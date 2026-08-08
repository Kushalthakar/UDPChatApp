//
//  MessageBoxView.swift
//  UDPChatApp
//
//  Created by Kushal Thakar on 14/07/26.
//

import SwiftUI

struct MessageBoxView: View {
    @State private var msgInfo = false
    
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
                Text(message.text)
                    .onLongPressGesture(minimumDuration: 2) {
                        msgInfo = true
                    }
                    .alert("Message Information", isPresented: $msgInfo) {
                        Button("Ok", role: .cancel) {}
                        
                    } message: {
                        let messageSentAt = message.sentAt.formatted(.dateTime)
                        Text("Send by: \(message.sender), Sent At: \(messageSentAt)")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
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
                                       sender: "Kushal",
                                       text: "Hi",
                                       sentAt: Date(),
                                       messageDirectoin: .sent))
}
