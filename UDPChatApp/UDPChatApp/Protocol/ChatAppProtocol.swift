//
//  ChatAppProtocol.swift
//  UDPChatApp
//
//  Created by Kushal Thakar on 12/07/26.
//

import Foundation

protocol ChatAppProtocol {
    func startListening(port: UInt16)
    func send(text: String,
              sender: String,
              host: String,
              port: UInt16)
    func stop()
}
