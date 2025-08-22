import SwiftUI

struct AIConversationBarView: View {
    @ObservedObject var aiContext: AIContextManager
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedConversation: AIConversationEntry?
    
    var body: some View {
        VStack(spacing: 0) {
            // Conversation tabs like Cursor
            if !aiContext.conversationHistory.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(aiContext.conversationHistory.suffix(5)) { conversation in
                            ConversationTabView(
                                conversation: conversation,
                                isSelected: selectedConversation?.id == conversation.id,
                                onSelect: {
                                    selectedConversation = conversation
                                }
                            )
                            .environmentObject(themeManager)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                }
                .frame(height: 36)
                .background(themeManager.currentTheme.backgroundColor.opacity(0.5))
                
                // Selected conversation content
                if let selected = selectedConversation {
                    ConversationContentView(conversation: selected)
                        .environmentObject(themeManager)
                        .frame(maxHeight: 120)
                } else if let latest = aiContext.conversationHistory.last {
                    ConversationContentView(conversation: latest)
                        .environmentObject(themeManager)
                        .frame(maxHeight: 120)
                        .onAppear {
                            selectedConversation = latest
                        }
                }
            }
        }
        .background(themeManager.currentTheme.backgroundColor.opacity(0.95))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.2)),
            alignment: .bottom
        )
    }
}

struct ConversationTabView: View {
    let conversation: AIConversationEntry
    let isSelected: Bool
    let onSelect: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 6) {
                Image(systemName: "message")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? themeManager.currentTheme.accentColor : themeManager.currentTheme.foregroundColor.opacity(0.6))
                
                Text(conversation.prompt.prefix(30) + (conversation.prompt.count > 30 ? "..." : ""))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isSelected ? themeManager.currentTheme.accentColor : themeManager.currentTheme.foregroundColor.opacity(0.7))
                    .lineLimit(1)
                
                if !conversation.attachedCommands.isEmpty {
                    Image(systemName: "paperclip")
                        .font(.system(size: 9))
                        .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.5))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? themeManager.currentTheme.accentColor.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? themeManager.currentTheme.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ConversationContentView: View {
    let conversation: AIConversationEntry
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                // User prompt
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(themeManager.currentTheme.accentColor)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("You")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(themeManager.currentTheme.accentColor)
                        
                        Text(conversation.prompt)
                            .font(.system(size: 12))
                            .foregroundColor(themeManager.currentTheme.foregroundColor)
                            .textSelection(.enabled)
                    }
                    
                    Spacer()
                }
                
                // Show attached commands
                if !conversation.attachedCommands.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Context:")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.6))
                        
                        ForEach(conversation.attachedCommands.prefix(2)) { command in
                            HStack(spacing: 6) {
                                Image(systemName: "terminal")
                                    .font(.system(size: 9))
                                    .foregroundColor(command.isError ? themeManager.currentTheme.errorColor : themeManager.currentTheme.accentColor)
                                
                                Text(command.command)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.8))
                                    .lineLimit(1)
                                
                                if command.isError {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 8))
                                        .foregroundColor(themeManager.currentTheme.errorColor)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(themeManager.currentTheme.foregroundColor.opacity(0.05))
                            .cornerRadius(3)
                        }
                        
                        if conversation.attachedCommands.count > 2 {
                            Text("... and \(conversation.attachedCommands.count - 2) more")
                                .font(.system(size: 9))
                                .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.5))
                                .padding(.horizontal, 8)
                        }
                    }
                }
                
                // AI response
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 14))
                        .foregroundColor(themeManager.currentTheme.accentColor.opacity(0.8))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Agent")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(themeManager.currentTheme.accentColor.opacity(0.8))
                        
                        Text(conversation.response)
                            .font(.system(size: 12))
                            .foregroundColor(themeManager.currentTheme.foregroundColor)
                            .textSelection(.enabled)
                    }
                    
                    Spacer()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}

#Preview {
    @Previewable @StateObject var themeManager = ThemeManager()
    @Previewable @StateObject var aiContext = AIContextManager()
    
    return AIConversationBarView(aiContext: aiContext)
        .environmentObject(themeManager)
        .frame(height: 200)
}
