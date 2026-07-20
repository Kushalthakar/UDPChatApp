//
//  ChatView.swift
//  UDPChatApp
//
//  Created by Kushal Thakar on 12/07/26.
//

import SwiftUI

struct ChatView: View {
    @StateObject private var chatViewModel: ChatViewModel = ChatViewModel()
    
    @State private var displayName: String = ""
    @State private var localPort: String = ""
    @State private var peerIPAddress: String = ""
    @State private var peerPort: String = ""
    @State private var messageText: String = ""
    @State private var validationMessage: String = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 7) {
                connection
                message
                messageInput
            }
            .padding()
            .onDisappear() {
                chatViewModel.stop()
            }
        }
    }
    
    private var connection: some View {
        VStack(spacing: 7) {
            Text("Configure")
                .font(.title2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                
            
            TextField("Your Name", text: $displayName)
            
            TextField("Local Port", text: $localPort)
                .keyboardType(.numberPad)
            
            TextField("Peer Port", text: $peerPort)
                .keyboardType(.numberPad)
            
            TextField("Peer IP Address", text: $peerIPAddress)
                .keyboardType(.numbersAndPunctuation)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            
            HStack {
                Button("Start") {
                    startListener()
                }
                .buttonStyle(.borderedProminent)
                .disabled(chatViewModel.isListening)
                
                Button("Stop", role: .destructive) {
                    chatViewModel.stop()
                }
                .buttonStyle(.bordered)
                .disabled(!chatViewModel.isListening)
                
                if !validationMessage.isEmpty {
                    Text(validationMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(.vertical, 7)
            
            HStack {
                Circle()
                    .fill(chatViewModel.isListening ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)
                
                Text(chatViewModel.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
        }
        .shadow(radius: 1)
        .frame(maxWidth: .infinity)
    }
    
    private var message: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if chatViewModel.messages.isEmpty {
                        ContentUnavailableView(
                            "No Message",
                            systemImage: "bubble.left.and.bubble.right",
                            description: Text("Send the Message")
                        )
                    }
                    
                    ForEach(chatViewModel.messages) { message in
                        MessageBoxView(message: message)
                            .id(message.id)
                    }
                }
            }
            .onChange(of: chatViewModel.messages.count) { _ in
                guard let lastMessage = chatViewModel.messages.last else {
                    return
                }
                withAnimation {
                    proxy.scrollTo( lastMessage.id,
                                    anchor: .bottom)
                }
            }
        }
    }
    
    private var messageInput: some View {
        HStack {
            TextField("Enter message",
                      text: $messageText,
                      axis: .vertical)
            .textFieldStyle(.roundedBorder)
            .lineLimit(1...4)
            .onSubmit {
                sendMessage()
            }
            
            Button {
                sendMessage()
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.title3)
            }
            .buttonStyle(.borderedProminent)
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
            )
        }
        .shadow(radius: 2)
    }
    
    private func startListener() {
        guard let port = UInt16(localPort) else {
            validationMessage = "Enter the local port number"
            return
        }
        
        validationMessage = ""
        chatViewModel.startListening(port: port)
    }
    
    private func sendMessage() {
        guard let port = UInt16(peerPort) else {
            validationMessage = "Enter peer port number"
            return
        }
        
        guard !peerIPAddress
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty else {
            validationMessage = "Enter the other device's IP address"
            return
        }
        
        validationMessage = ""
        
        chatViewModel.send(text: messageText,
                           sender: displayName,
                           host: peerIPAddress,
                           port: port)
        
        messageText = ""
    }
}

#Preview {
    ChatView()
}
