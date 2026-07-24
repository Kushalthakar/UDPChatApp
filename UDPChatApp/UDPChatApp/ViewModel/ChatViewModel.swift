//
//  ChatService.swift
//  UDPChatApp
//
//  Created by Kushal Thakar on 12/07/26.
//

import Foundation
import Combine
import UIKit
@preconcurrency import Network

final class ChatViewModel: ObservableObject, @unchecked Sendable, ChatAppProtocol {
    @Published private(set) var peers: [DiscoveredPeer] = []
    @Published private(set) var messages: [Message] = []
    @Published private(set) var status: String = "Not Listening"
    @Published private(set) var isListening: Bool = false
    
    private static let serviceType = "_udpchat._udp"
    private let serviceName: String
    private var browser: NWBrowser?
    private var listener: NWListener?
    private var incomingConnection: [ObjectIdentifier: NWConnection] = [:]
    private var outgoingConnection: [ObjectIdentifier: NWConnection] = [:]
    private var receivedMessageIDs: Set<UUID> = []
    private var queue = DispatchQueue ( label: "com.example.UDPChatApp.network" )
    
    let localDisplayName: String
    
    init() {
        let rawDeviceName: String
        
        #if targetEnvironment(simulator)
        rawDeviceName = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? "iOS Simulator"
        #else
        rawDeviceName = UIDevice.current.name
        #endif
        
        let trimmedName = rawDeviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let safeName = trimmedName.isEmpty ? "iOS Device" : trimmedName
        
        localDisplayName = safeName
        
        let suffix = UUID()
            .uuidString
            .prefix(4)
            .uppercased()
        
        serviceName = "\(String(safeName.prefix(35)))-\(suffix)"
     }
    
    deinit {
        listener?.cancel()
        browser?.cancel()
        
        incomingConnection.values.forEach {
            $0.cancel()
        }
        outgoingConnection.values.forEach {
            $0.cancel()
        }
    }
    
    func start() {
        status("Starting UDP listener")
        
        queue.async { [weak self] in
            guard let self else {
                return
            }
            
            guard self.listener == nil,
                  self.browser == nil else {
                return
            }
            
            do {
                try self.startListening()
                self.startBrowser()
            } catch {
                self.status("Could not start UDP Chat App: " + error.localizedDescription, isListening: false)
            }
        }
    }
    
    func startListening() throws {
        let parameters = Self.makeUDPParemeter()
        
        let newListener = try NWListener(using: parameters)
        
        newListener.service = NWListener.Service(name: serviceName,
                                                 type: Self.serviceType)
        
        newListener.stateUpdateHandler = { [weak self] state in
            guard let self else {
                return
            }
            
            switch state {
            case .ready:
                let portDestination = newListener.port.map{String($0.rawValue)} ?? "automatic"
                status("Listening on automatic UDP port " + portDestination, isListening: true)
                
            case .waiting(let error):
                status("UDP listener waiting: " + error.localizedDescription, isListening: false)
                
            case .failed(let error):
                status("UDP listener failed: " + error.localizedDescription, isListening: false)
                self.stopNetworkObjects()
                
            case .cancelled:
                status("UDP listener stopped", isListening: false)
                
            default: break
            }
        }
        
        newListener.serviceRegistrationUpdateHandler = {
            [weak self] change in
            guard let self else {
                return
            }
            switch change {
            case .add:
                status("Ready as \(self.localDisplayName)", isListening: true)
                
            case .remove:
                status("Bonjour service was removed", isListening: false)
                
            @unknown default:
                break
            }
        }
        
        newListener.newConnectionHandler = {[weak self] connection in
            self?.acceptIncomingConnection(connection)
        }
        
        listener = newListener
        newListener.start(queue: queue)
    }
    
    func send(text: String,
              to peer: DiscoveredPeer) {
        
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanText.isEmpty else {
            return
        }
        
        let packet = Packet(sender: localDisplayName,
                            text: cleanText)
        
        let encoded = JSONEncoder()
        encoded.dateEncodingStrategy = .iso8601
        
        let data: Data
        
        do {
            data = try encoded.encode(packet)
        } catch {
            status("Could not encode message: " + error.localizedDescription)
            return
        }
        
        queue.async { [weak self] in
            guard let self else { return }
            
            let connection = NWConnection(to: peer.endpoint,
                                          using: Self.makeUDPParemeter())
            
            let identifier = ObjectIdentifier(connection)
            self.outgoingConnection[identifier] = connection
            
            connection.stateUpdateHandler = {
                [weak self, weak connection] state in
                
                guard let self, let connection else {
                    return
                }
                
                switch state {
                case .ready:
                    status("Sending to \(peer.name)")
                    
                case .waiting(let error):
                    status("Waiting for \(peer.name): " + error.localizedDescription)
                    
                case .failed(let error):
                    status("Send connection failed: " + error.localizedDescription)
                    self.finishOutgoingConnection(connection)
                    
                case .cancelled:
                    self.outgoingConnection.removeValue(forKey: ObjectIdentifier(connection))
                    
                default:
                    break
                }
            }
            
            connection.start(queue: queue)
            
            connection.send(content: data,
                            contentContext: .defaultMessage,
                            isComplete: true,
                            completion: .contentProcessed {
                [weak self, weak connection] error in
                guard let self, let connection else {
                    return
                }
                
                if let error {
                    status("Send failed: " + error.localizedDescription)
                } else {
                    self.appendSentMessage(packet)
                    status("Message sent to: \(peer.name)")
                }
                self.finishOutgoingConnection(connection)
            })
        }
    }
    
    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.stopNetworkObjects()
            self.status("UDP Chat Stopped", isListening: false)
            DispatchQueue.main.async {
                self.peers = []
            }
        }
    }
    
    private static func makeUDPParemeter() -> NWParameters {
        let parameters = NWParameters.udp
        parameters.includePeerToPeer = true
        return parameters
    }
    
    private func startBrowser() {
        let parameters = Self.makeUDPParemeter()
        
        let descriptor = NWBrowser.Descriptor.bonjour(type: Self.serviceType,
                                                      domain: nil)
        let newBrowser = NWBrowser(for: descriptor, using: parameters)
        
        newBrowser.stateUpdateHandler = {
            [weak self] state in
            guard let self else {
                return
            }
            
            switch state {
            case .ready:
                self.status("Seacrching for nearby UDP peer..", isListening: true)
                
            case .waiting(let error):
                self.status("Peer discovery waiting: " + error.localizedDescription)
                
            case .failed(let error):
                self.status("Peer discovery failed: " + error.localizedDescription)
                
            case .cancelled:
                break
                
            default:
                break
            }
        }
        
        newBrowser.browseResultsChangedHandler = {
            [weak self] results, _ in
            self?.updateDiscoveredPeers(results)
        }
        
        browser = newBrowser
        newBrowser.start(queue: queue)
        
    }
    
    private func updateDiscoveredPeers(_ results: Set<NWBrowser.Result>) {
        let discoveredPeers = results.compactMap {
            result -> DiscoveredPeer? in
            guard case let .service(
                name,
                _,
                _,
                _
            ) = result.endpoint else {
                return nil
            }
            
            guard name != serviceName else {
                return nil
            }
            
            return DiscoveredPeer(
                endpoint: result.endpoint,
                name: friendlyName(from: name)
            )
        }
            .sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            
            self.peers = discoveredPeers
            
            if discoveredPeers.isEmpty {
                self.status = "No nearby UDP peers found"
            } else {
                self.status = "\(discoveredPeers.count) peer" + (discoveredPeers.count == 1 ? "" : "s") + " found"
            }
            
        }
    }
    
    private func friendlyName(from bonjourName: String) -> String {
        guard bonjourName.count > 5 else {
            return bonjourName
        }
        
        let suffixStart = bonjourName.index(bonjourName.endIndex,
        offsetBy: -5)
        let possibleSuffix = bonjourName[suffixStart...]
        
        guard possibleSuffix.first == "_" else {
            return bonjourName
        }
        
        return String(bonjourName[..<suffixStart])
    }
    
    private func acceptIncomingConnection(_ connection: NWConnection) {
        let identifier = ObjectIdentifier(connection)
        incomingConnection[identifier] = connection
        
        connection.stateUpdateHandler = {
            [weak self, weak connection] state in
            guard let self, let connection else { return }
            
            switch state {
            case .failed(let error):
                self.status("Received connection failed: \(error.localizedDescription)")
                self.removeIncomingConnection(connection)
                
            case .cancelled:
                self.removeIncomingConnection(connection)
                
            default:
                break
            }
        }
        
        connection.start(queue: queue)
        receiveNextMessage(on: connection)
        
    }
    
    private func receiveNextMessage(on connection: NWConnection) {
        connection.receiveMessage { [weak self, weak connection] data, _, _, error in
            guard let self, let connection else { return }
            
            if let data, !data.isEmpty {
                self.processReceivedData(data)
            }
            
            if let error {
                self.status("Receive Error: \(error.localizedDescription)")
                self.removeIncomingConnection(connection)
                connection.cancel()
                return
            }
            self.receiveNextMessage(on: connection)
        }
    }
    
    private func processReceivedData(_ data: Data){
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let packet = try decoder.decode(Packet.self,
                                            from: data)
            
            guard packet.application == "UDPChatApp",
                  packet.version == 1 else {
                status("Received an unsupported packet")
                return
            }
            
            guard !receivedMessageIDs.contains(packet.id) else {
                return
            }
            
            receivedMessageIDs.insert(packet.id)
            
            let message = Message(id: packet.id,
                                  sender: packet.sender,
                                  text: packet.text,
                                  sentAt: packet.sentAt,
                                  messageDirectoin: .received)
            
            DispatchQueue.main.async { [weak self] in
                self?.messages.append(message)
                self?.status = "Message received from \(packet.sender)"
            }
        } catch {
            guard let text = String(data: data, encoding: .utf8) else {
                status("Received an unreadable UDP data")
                return
            }
            
            let message = Message(id: UUID(),
                                  sender: "UDP Peer",
                                  text: text,
                                  sentAt: Date(),
                                  messageDirectoin: .received)
            
            DispatchQueue.main.async {[weak self] in
                self?.messages.append(message)
                
            }
        }
    }
    
    private func appendSentMessage(_ packet: Packet) {
        let message = Message(id: packet.id,
                              sender: packet.sender,
                              text: packet.text,
                              sentAt: packet.sentAt,
                              messageDirectoin: .sent)
        
        DispatchQueue.main.async { [weak self] in
            self?.messages.append(message)
        }
    }
    
    private func removeIncomingConnection(_ connection: NWConnection) {
        incomingConnection.removeValue(forKey: ObjectIdentifier(connection))
    }
    
    private func finishOutgoingConnection(_ connection: NWConnection) {
        outgoingConnection.removeValue(forKey: ObjectIdentifier(connection))
        connection.cancel()
    }
    
    private func status(_ status: String,
                        isListening listeningValue: Bool? = nil) {
        DispatchQueue.main.async { [weak self] in
            self?.status = status
            if let listeningValue {
                self?.isListening = listeningValue
            }
        }
    }
    
    private func stopNetworkObjects() {
        listener?.cancel()
        listener = nil
        browser?.cancel()
        browser = nil
        incomingConnection.values.forEach {
            $0.cancel()
        }
        outgoingConnection.values.forEach {
            $0.cancel()
        }
        
        incomingConnection.removeAll()
        outgoingConnection.removeAll()
    }
}
