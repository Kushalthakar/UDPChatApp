//
//  ChatModel.swift
//  UDPChatApp
//
//  Created by Kushal Thakar on 12/07/26.
//

import Foundation

struct Packet: Codable {
    let id: UUID
    let sender: String
    let text: String
    let sentAt: Date
}

struct Message: Identifiable {
    enum messageDirection: Equatable {
        case sent
        case received
    }
    
    let id: UUID
    let sender: String
    let text: String
    let sentAt: Date
    let messageDirectoin: messageDirection
}
