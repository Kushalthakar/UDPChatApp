//
//  ChatModel.swift
//  UDPChatApp
//
//  Created by Kushal Thakar on 12/07/26.
//

import Foundation
@preconcurrency import Network

struct Packet: Codable, Sendable {
    let id: UUID
    let application: String
    let version: Int
    let sender: String
    let text: String
    let sentAt: Date
    
    init(id: UUID = UUID(),
         sender: String,
         text: String,
         sentAt: Date = Date()) {
        self.id = id
        self.application = "UDPChatApp"
        self.version = 1
        self.sender = sender
        self.text = text
        self.sentAt = sentAt
    }
}

struct Message: Identifiable, Sendable {
    enum MessageDirection: Equatable {
        case sent
        case received
    }
    
    let id: UUID
    let sender: String
    let text: String
    let sentAt: Date
    let messageDirectoin: MessageDirection
}

struct DiscoveredPeer: Identifiable, Hashable, @unchecked Sendable {
    let endpoint: NWEndpoint
    let name: String
    
    var id: String {
        endpoint.debugDescription
    }
    
    static func == (lhs: DiscoveredPeer, rhs: DiscoveredPeer) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct ValidationMessage {
    enum PortType {
        case localPort
        case peerPort
        case peerIPAddress
    }
}
