//
//  MessageBoxView.swift
//  UDPChatApp
//
//  Created by Kushal Thakar on 14/07/26.
//

import SwiftUI

struct MessageBoxView: View {
    let message: Message
    
    private var isSent: Bool {
        message.messageDirectoin == .sent
    }
    
    var body: some View {
        HStack {
            if isSent {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: isSent ? .trailing : .leading, spacing: 4) {
                Text(message.sender)
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Text(message.text)
                
                Text(message.sentAt, style: .time)
                    .font(.caption2)
                    .opacity(0.7)
            }
            .padding(12)
            .foregroundStyle(isSent ? Color.white : Color.primary)
            .background(isSent ? Color.blue : Color.secondary.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            
            if !isSent {
                Spacer(minLength: 50)
            }
        }
    }
}

#Preview {
    MessageBoxView(message: Message(id: UUID(),
                                       sender: "",
                                       text: "",
                                       sentAt: Date(),
                                       messageDirectoin: .sent))
}
