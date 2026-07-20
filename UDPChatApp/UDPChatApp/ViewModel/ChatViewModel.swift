//
//  ChatService.swift
//  UDPChatApp
//
//  Created by Kushal Thakar on 12/07/26.
//

import Foundation
import Combine
@preconcurrency import Network

final class ChatViewModel: ObservableObject, @unchecked Sendable {
    @Published private(set) var messages: [Message] = []
    @Published private(set) var status: String = "Not Listening"
    @Published private(set) var isListening: Bool = false
    
    private(set) var listener: NWListener?
    private(set) var incomingConnection: [ObjectIdentifier: NWConnection] = [:]
    private(set) var outgoingConnection: [ObjectIdentifier: NWConnection] = [:]
    private(set) var queue = DispatchQueue ( label: "com.example.UDPChatApp.network" )
    
    init() {}
    
    deinit { listener?.cancel() }
    
    func startListening(port: UInt16) {
        guard listener == nil else {
            status("Listener is already running")
            return
        }
        guard let networkPort = NWEndpoint.Port(rawValue: port) else {
            status("Invalid listening port")
            return
        }
        do {
            let newListener = try NWListener(using: .udp,
                                             on: networkPort)
            
            newListener.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    self?.status("Listening on UDP port \(port)",
                                 isListening: true)
                case .waiting(let error):
                    self?.status("Listener waiting: \(error.localizedDescription)")
                case .failed(let error):
                    self?.status("Listener failed: \(error.localizedDescription)",
                                 isListening: false)
                case .cancelled:
                    self?.status("Listener stopped",
                                 isListening: false)
                default:
                    break
                }
            }
            newListener.newConnectionHandler = { [weak self] connection in
                self?.acceptIncomingConnection(connection)
            }
            listener = newListener
            newListener.start(queue: queue)
        } catch {
            status("Could not start listener: \(error.localizedDescription)",
                   isListening: false)
        }
    }
    
    func send(text: String,
              sender: String,
              host: String,
              port: UInt16) {
        
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanText.isEmpty else {
            status("Enter a message")
            return
        }
        
        guard !cleanHost.isEmpty else {
            status("Enter the Peer IP address")
            return
        }
        
        guard let destinationPort = NWEndpoint.Port(rawValue: port) else {
            status("Invalid destination port")
            return
        }
        
        let packet = Packet(id: UUID(),
                            sender: sender.isEmpty ? "unknown" : sender,
                            text: cleanText,
                            sentAt: Date())
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let data: Data
        
        do {
            data = try encoder.encode(packet)
        } catch {
            status("Encoding failed: \(error.localizedDescription)")
            return
        }
        
        let connection = NWConnection(host: NWEndpoint.Host(cleanHost),
                                      port: destinationPort,
                                      using: .udp)
        queue.async { [weak self] in
            guard let self else { return }
            let identifier = ObjectIdentifier(connection)
            self.outgoingConnection[identifier] = connection
            
            var messageWasSent = false
            
            connection.stateUpdateHandler = {
                [weak self, weak connection] state in
                
                guard let self, let connection else {
                    return
                }
                
                switch state {
                case .ready:
                    guard !messageWasSent else {
                        return
                    }
                    messageWasSent = true
                    
                    connection.send(content: data,
                                    contentContext: .defaultMessage,
                                    isComplete: true,
                                    completion: .contentProcessed { error in
                        if let error {
                            self.status("Send failed: \(error.localizedDescription)")
                        } else {
                            self.appendSentMessage(packet)
                            
                            self.status("Message sent to \(cleanHost): \(port)")
                        }
                        self.finishOutgoingConnection(connection)
                    })
                case .waiting(let error):
                    self.status("Connection waiting: \(error.localizedDescription)")
                case .failed(let error):
                    self.status("Connection failed: \(error.localizedDescription)")
                    self.finishOutgoingConnection(connection)
                case .cancelled:
                    self.outgoingConnection.removeValue(forKey: ObjectIdentifier(connection))
                default:
                    break
                }
                
            }
            connection.start(queue: self.queue)
        }
    }
    
    func stop() {
        listener?.cancel()
        listener = nil
        
        queue.async { [weak self] in
            guard let self else { return }
            self.incomingConnection.values.forEach {
                $0.cancel()
            }
            
            self.outgoingConnection.values.forEach {
                $0.cancel()
            }
            
            self.incomingConnection.removeAll()
            self.outgoingConnection.removeAll()
        }
        
        status("Listener stopped",
               isListening: false)
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
        
        if let packet = try? decoder.decode(Packet.self,
                                            from: data) {
            let message = Message(id: packet.id,
                                  sender: packet.sender,
                                  text: packet.text,
                                  sentAt: packet.sentAt,
                                  messageDirectoin: .received)
            
            DispatchQueue.main.async { [weak self] in
                self?.messages.append(message)
            }
            return
        }
        
        if let text = String(data: data, encoding: .utf8) {
            let message = Message(id: UUID(),
                                  sender: "Peer",
                                  text: text,
                                  sentAt: Date(),
                                  messageDirectoin: .received)
            
            DispatchQueue.main.async { [weak self] in
                self?.messages.append(message)
            }
        } else {
            status("Received an unsupported UDP Payload")
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
}
