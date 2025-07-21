import SwiftUI

struct GroupChatView: View {
    let groupId: String
    let groupName: String
    
    @State private var messageText = ""
    @State private var messages: [ChatMessage] = []
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Messages List
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(messages) { message in
                                ChatMessageRow(message: message)
                            }
                            
                            // Coming Soon Message
                            ComingSoonCard()
                                .id("bottom")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                    }
                    .onChange(of: messages.count) { _ in
                        withAnimation {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
                
                // Input Area
                VStack(spacing: 0) {
                    Divider()
                        .background(Color(.systemGray5).opacity(0.3))
                    
                    HStack(spacing: 12) {
                        // Text Field
                        HStack(spacing: 12) {
                            TextField("Type a message...", text: $messageText)
                                .foregroundColor(.white)
                                .focused($isTextFieldFocused)
                                .disabled(true) // Disabled until backend is ready
                            
                            if !messageText.isEmpty {
                                Button(action: {
                                    messageText = ""
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6).opacity(0.3))
                        .cornerRadius(20)
                        
                        // Send Button
                        Button(action: {
                            sendMessage()
                        }) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 20))
                                .foregroundColor(messageText.isEmpty ? .gray : .green)
                                .rotationEffect(.degrees(45))
                        }
                        .disabled(messageText.isEmpty || true) // Disabled until backend is ready
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(Color.black)
            }
        }
        .navigationTitle(groupName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    // Show group info
                }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.green)
                }
            }
        }
        .onAppear {
            loadMockMessages()
        }
    }
    
    private func sendMessage() {
        // This will be implemented when backend is ready
        let mockMessage = ChatMessage(
            id: UUID().uuidString,
            senderId: "currentUser",
            senderName: "You",
            message: messageText,
            timestamp: Date(),
            isCurrentUser: true
        )
        
        messages.append(mockMessage)
        messageText = ""
        isTextFieldFocused = false
        
        HapticManager.shared.impact(.light)
    }
    
    private func loadMockMessages() {
        // Mock messages for UI preview
        messages = []
    }
}

// MARK: - Chat Message Row

struct ChatMessageRow: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isCurrentUser {
                Spacer()
            }
            
            VStack(alignment: message.isCurrentUser ? .trailing : .leading, spacing: 4) {
                if !message.isCurrentUser {
                    Text(message.senderName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(message.message)
                    .font(.subheadline)
                    .foregroundColor(message.isCurrentUser ? .black : .white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        message.isCurrentUser ? Color.green : Color(.systemGray6).opacity(0.3)
                    )
                    .cornerRadius(20, corners: message.isCurrentUser ? [.topLeft, .topRight, .bottomLeft] : [.topLeft, .topRight, .bottomRight])
                
                Text(formatTimestamp(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: 280, alignment: message.isCurrentUser ? .trailing : .leading)
            
            if !message.isCurrentUser {
                Spacer()
            }
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else if calendar.isDateInYesterday(date) {
            formatter.dateFormat = "'Yesterday' HH:mm"
        } else {
            formatter.dateFormat = "MMM d, HH:mm"
        }
        
        return formatter.string(from: date)
    }
}

// MARK: - Coming Soon Card

struct ComingSoonCard: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("Group Chat Coming Soon!")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("Chat with your group members right here in the app. This feature will be available in the next update.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(20)
        .padding(.vertical, 40)
    }
}

// MARK: - Supporting Types

struct ChatMessage: Identifiable {
    let id: String
    let senderId: String
    let senderName: String
    let message: String
    let timestamp: Date
    let isCurrentUser: Bool
}

// MARK: - Corner Radius Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        GroupChatView(
            groupId: "preview-group",
            groupName: "Weekend Warriors"
        )
    }
    .preferredColorScheme(.dark)
}