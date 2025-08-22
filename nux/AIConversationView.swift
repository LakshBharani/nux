import SwiftUI

struct AIConversationView: View {
    @ObservedObject var aiContext: AIContextManager
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: 16) {
                if aiContext.conversationHistory.isEmpty && !aiContext.isProcessing {
                    // Empty state for AI mode
                    AIEmptyStateView()
                } else {
                    // Conversation history
                    LazyVStack(alignment: .leading, spacing: 20) {
                        ForEach(aiContext.conversationHistory) { entry in
                            AIConversationEntryView(entry: entry)
                                .id(entry.id)
                        }
                        
                        // Show current processing state
                        if aiContext.isProcessing {
                            AIProcessingView()
                        }
                        
                        // Anchor at bottom for scrolling
                        Spacer().frame(height: 20).id("ai-bottom")
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .onChange(of: aiContext.conversationHistory.count) {
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo("ai-bottom", anchor: .bottom)
                }
            }
            .onChange(of: aiContext.isProcessing) {
                if aiContext.isProcessing {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo("ai-bottom", anchor: .bottom)
                    }
                }
            }
        }
    }
}

struct AIConversationEntryView: View {
    let entry: AIConversationEntry
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // User prompt
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(themeManager.currentTheme.accentColor)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("You")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(themeManager.currentTheme.accentColor)
                    
                    Text(entry.prompt)
                        .font(.system(.body, design: .default))
                        .foregroundColor(themeManager.currentTheme.foregroundColor)
                        .textSelection(.enabled)
                    
                    // Show attached commands if any
                    if !entry.attachedCommands.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Attached Context:")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.6))
                            
                            ForEach(entry.attachedCommands) { command in
                                AttachedCommandView(command: command)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                
                Spacer()
            }
            
            // AI response
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 18))
                    .foregroundColor(themeManager.currentTheme.accentColor.opacity(0.8))
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("AI Assistant")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(themeManager.currentTheme.accentColor.opacity(0.8))
                    
                    Text(entry.response)
                        .font(.system(.body, design: .default))
                        .foregroundColor(themeManager.currentTheme.foregroundColor)
                        .textSelection(.enabled)
                }
                
                Spacer()
            }
            
            // Timestamp
            HStack {
                Spacer()
                Text(entry.timestamp, style: .time)
                    .font(.system(size: 10))
                    .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.5))
            }
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(themeManager.currentTheme.backgroundColor.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(themeManager.currentTheme.foregroundColor.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct AttachedCommandView: View {
    let command: AIAttachedCommand
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "terminal")
                    .font(.system(size: 10))
                    .foregroundColor(command.isError ? themeManager.currentTheme.errorColor : themeManager.currentTheme.accentColor)
                
                Text(command.command)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(themeManager.currentTheme.foregroundColor)
                
                Spacer()
                
                if command.isError {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9))
                        .foregroundColor(themeManager.currentTheme.errorColor)
                }
            }
            
            if !command.output.isEmpty {
                Text(command.output)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(command.isError ? themeManager.currentTheme.errorColor : themeManager.currentTheme.foregroundColor.opacity(0.8))
                    .lineLimit(3)
                    .padding(.leading, 16)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(themeManager.currentTheme.foregroundColor.opacity(0.05))
        )
    }
}

struct AIProcessingView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 18))
                .foregroundColor(themeManager.currentTheme.accentColor.opacity(0.8))
            
            VStack(alignment: .leading, spacing: 8) {
                Text("AI Assistant")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(themeManager.currentTheme.accentColor.opacity(0.8))
                
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    
                    Text("Thinking...")
                        .font(.system(.body, design: .default))
                        .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.6))
                        .italic()
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

struct AIEmptyStateView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundColor(themeManager.currentTheme.accentColor.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("AI Assistant Mode")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(themeManager.currentTheme.foregroundColor)
                
                Text("Ask questions about your terminal session, get command suggestions, or troubleshoot issues.")
                    .font(.system(size: 14))
                    .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Tips:")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(themeManager.currentTheme.accentColor)
                
                HStack(alignment: .top, spacing: 8) {
                    Text("⌘↑")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(themeManager.currentTheme.accentColor)
                    Text("Attach latest command as context")
                        .font(.system(size: 11))
                        .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.7))
                }
                
                HStack(alignment: .top, spacing: 8) {
                    Text("⌘I")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(themeManager.currentTheme.accentColor)
                    Text("Toggle Agent mode on/off")
                        .font(.system(size: 11))
                        .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.7))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(themeManager.currentTheme.accentColor.opacity(0.1))
            .cornerRadius(8)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    @Previewable @StateObject var themeManager = ThemeManager()
    @Previewable @StateObject var aiContext = AIContextManager()
    
    return AIConversationView(aiContext: aiContext)
        .environmentObject(themeManager)
        .padding()
}
