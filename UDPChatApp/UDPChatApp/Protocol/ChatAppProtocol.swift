//
//  ChatAppProtocol.swift
//  UDPChatApp
//
//  Created by Kushal Thakar on 12/07/26.
//

import Foundation

protocol ChatAppProtocol {
    func start()
    func startListening() throws
    func send(text: String,
              to peer: DiscoveredPeer)
    func stop()
}
