//
//  ChatView.swift
//  UDPChatApp
//
//  Created by Kushal Thakar on 12/07/26.
//

import SwiftUI

struct ChatView: View {
    @StateObject private var chatViewModel: ChatViewModel = ChatViewModel()
    
    @State private var selectedPeerID: String?
    @State private var messageText: String = ""
    
    private var selectedPeer: DiscoveredPeer? {
        chatViewModel.peers.first {
            $0.id == selectedPeerID
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 7) {
                status
                peer
                message
                messageInput
            }
            .padding()
            .onAppear{
                chatViewModel.start()
            }
            .onChange(of: chatViewModel.peers.map(\.id)) {
                peerIDs in updateSelectedPeer(availablePeerIDs: peerIDs)
            }
            .onDisappear() {
                chatViewModel.stop()
            }
        }
    }
    
    private var status: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill( chatViewModel.isListening ? Color.green : Color.orange)
                    .frame(width: 10, height: 10)
                Text(chatViewModel.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer()
            }
            
            HStack {
                Image(systemName: "iphone")
                
                Text("You: \(chatViewModel.localDisplayName)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button {
                    chatViewModel.stop()
                    chatViewModel.start()
                } label: {
                    Image ( systemName: "arrow.clockwise" )
                }
                .accessibilityLabel("Restart discovery")
            }
        }
    }
    
    private var peer: some View {
        GroupBox("NearBy Peer") {
            if chatViewModel.peers.isEmpty {
                VStack(spacing: 8) {
                    ProgressView()
                    
                    Text("Open UDP Chat on another simulator " + " or device.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 70)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(chatViewModel.peers) {
                            peer in peerButton(peer)
                        }
                    }
                }
            }
        }
    }
    
    private func peerButton(_ peer: DiscoveredPeer) -> some View {
        let isSelected = selectedPeerID == peer.id
        return Button {
            selectedPeerID = peer.id
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                Text(peer.name)
                    .lineLimit(1)
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
    
    private var message: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if chatViewModel.messages.isEmpty {
                        emptyMessageView
                    } else {
                        ForEach(chatViewModel.messages) {
                            message in MessageBoxView(
                                message: message
                            )
                            .id(message.id)
                        }
                    }
                }
            }
            .onChange(of: chatViewModel.messages.count) { _ in
                guard let lastMessage = chatViewModel.messages.last else {
                    return
                }
                
                withAnimation {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
        }
    }
    
    private var emptyMessageView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)
            
            Text(selectedPeer == nil ? "Waiting for another UDP Chat peer." : "Send a message to \(selectedPeer?.name ?? "the peer")")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 230)
    }
    
    private var messageInput: some View {
        HStack(alignment: .bottom) {
            TextField(selectedPeer == nil ? "Waiting for peer..." : "Message \(selectedPeer?.name ?? "")",
                      text: $messageText,
                      axis: .vertical)
            .textFieldStyle(.roundedBorder)
            .lineLimit(1...4)
            .disabled(selectedPeer == nil)
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
            .disabled(selectedPeer == nil || messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
    
    private func sendMessage() {
        guard let selectedPeer else { return }
        
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !text.isEmpty else { return }
        
        chatViewModel.send(text: text,
                           to: selectedPeer)
        
        messageText = ""
    }
    
    private func updateSelectedPeer(availablePeerIDs: [String]) {
        if let selectedPeerID, availablePeerIDs.contains(selectedPeerID) {
            return
        }
        
        selectedPeerID = availablePeerIDs.first
    }
}

#Preview {
    ChatView()
}
