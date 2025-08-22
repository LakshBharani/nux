import SwiftUI
import AppKit

struct TerminalOutputRow: View {
    let output: TerminalOutput
    let outputIndex: Int
    let ownerCommandIndex: Int
    let allOutputs: [TerminalOutput]
    @Binding var hoveredCommandIndex: Int?
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var aiContext: AIContextManager
    @State private var isHovered = false
    private let buttonWidth: CGFloat = 170
    
    // Add binding to current command so we can update it directly
    @Binding var currentCommand: String
    
    // Check if this command has an AI response
    private var hasAIResponse: Bool {
        let hasResponse = aiContext.conversationHistory.contains { conversation in
            conversation.attachedCommands.contains { attached in
                attached.command == output.text && attached.timestamp == output.timestamp
            }
        }
        if output.type == .command && hasResponse {
            print("📱 [DEBUG] Rendering inline AI response for command: '\(output.text)'")
        }
        return hasResponse
    }
    
    // Get AI response for this command
    private var aiResponse: AIConversationEntry? {
        aiContext.conversationHistory.first { conversation in
            conversation.attachedCommands.contains { attached in
                attached.command == output.text && attached.timestamp == output.timestamp
            }
        }
    }
    
    // Find the command that caused this error
    private func findCommandForError(_ errorOutput: TerminalOutput) -> TerminalOutput? {
        for i in (0..<allOutputs.count).reversed() {
            if allOutputs[i].type == .command {
                return allOutputs[i]
            }
        }
        return nil
    }
    
    // Find AI response for a specific command
    private func findAIResponseForCommand(_ commandOutput: TerminalOutput) -> AIConversationEntry? {
        return aiContext.conversationHistory.first { conversation in
            conversation.attachedCommands.contains { attached in
                attached.command == commandOutput.text && attached.timestamp == commandOutput.timestamp
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if output.type == .command {
                // Divider above each command - full width
                Divider()
                    .background(themeManager.currentTheme.foregroundColor.opacity(0.1))
                    .padding(.vertical, 8)
                // Show directory and execution time above command
                if let directory = output.directory, let executionTime = output.executionTime {
                    HStack {
                        // Show full expanded path (do not collapse ~)
                        Text(directory)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.6))
                        
                        Text("(\(String(format: "%.3fs", executionTime)))")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.6))
                        
                        Spacer()
                        
                        // Reserved area for attach/remove button to prevent layout shift
                        HStack(spacing: 0) {
                            let attached = isOwnerAttached()
                            Button(action: {
                                if attached { removeCommandFromContext() } else { attachCommandAsContext() }
                            }) {
                                HStack(spacing: 6) {
                                    if attached {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 10, weight: .medium))
                                        Text("Remove context")
                                            .font(.system(size: 10, weight: .medium))
                                    } else {
                                        Image(systemName: "paperclip")
                                            .font(.system(size: 10, weight: .medium))
                                        Text("Attach as context")
                                            .font(.system(size: 10, weight: .medium))
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(attached ? themeManager.currentTheme.foregroundColor.opacity(0.08) : themeManager.currentTheme.accentColor.opacity(0.1))
                                .foregroundColor(attached ? themeManager.currentTheme.foregroundColor.opacity(0.75) : themeManager.currentTheme.accentColor)
                                .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                            .opacity(hoveredCommandIndex == ownerCommandIndex || attached ? 1 : 0)
                            .animation(.easeOut(duration: 0.12), value: hoveredCommandIndex == ownerCommandIndex || attached)
                        }
                        .frame(width: buttonWidth, alignment: .trailing)
                    }
                }
                
                // Command line
                HStack(alignment: .top, spacing: 12) {
                    Text(output.prompt)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(themeManager.currentTheme.accentColor)
                    
                    Text(output.text)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(colorForOutputType(output.type))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if output.type != .aiResponse {
                // Regular output (not commands and not AI responses)
                Text(output.text)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(colorForOutputType(output.type))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Show AI response for aiResponse type
            if output.type == .aiResponse {
                VStack(alignment: .leading, spacing: 0) {
                    // Find and render the AI response
                    if let conversationId = UUID(uuidString: output.text) {
                        let _ = print("🎨 [DEBUG] Looking for AI response with ID: \(conversationId)")
                        let _ = print("🎨 [DEBUG] Available conversation IDs: \(aiContext.conversationHistory.map { $0.id })")
                        
                        if let aiResponse = aiContext.conversationHistory.first(where: { $0.id == conversationId }) {
                            let _ = print("🎨 [DEBUG] Found AI response, rendering block")
                            AIResponseViews.generalAIResponseView(response: aiResponse, themeManager: themeManager)
                        } else {
                            let _ = print("🎨 [DEBUG] AI response not found in conversation history")
                            Text("AI Response not found (ID: \(conversationId))")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    } else {
                        let _ = print("🎨 [DEBUG] Invalid UUID in AI response text: '\(output.text)'")
                        Text("Invalid AI Response ID")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            
            // Inline error action strip below the error line
            if output.type == .error {
                inlineErrorActionStrip
                    .padding(.top, 8)
                
                // Show AI response directly connected to error box
                if let commandOutput = findCommandForError(output),
                   let aiResponse = findAIResponseForCommand(commandOutput) {
                    AIResponseViews.inlineAIResponseView(response: aiResponse, themeManager: themeManager)
                }
            }
        }
        .padding(.vertical, output.type == .command ? 0 : (output.type == .error ? 0 : 2))
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                hoveredCommandIndex = ownerCommandIndex
            } else if hoveredCommandIndex == ownerCommandIndex {
                hoveredCommandIndex = nil
            }
        }
    }
    
    private func debugNoAIResponse() {
        print("🔍 [DEBUG] No AI response found for command")
        print("🔍 [DEBUG] Available conversation entries: \(aiContext.conversationHistory.count)")
        for (i, entry) in aiContext.conversationHistory.enumerated() {
            print("🔍 [DEBUG] Entry \(i): attachedCommands.count = \(entry.attachedCommands.count)")
            for attached in entry.attachedCommands {
                print("🔍 [DEBUG]   - Command: '\(attached.command)', timestamp: \(attached.timestamp)")
            }
        }
    }
    
    private func attachCommandAsContext() {
        let followingOutputs = getOutputsAfterCommand(at: outputIndex, in: allOutputs)
        let attachedCommand = AIAttachedCommand(from: output, commandOutput: followingOutputs)
        
        // Avoid duplicates
        if !aiContext.attachedCommands.contains(where: { $0.command == attachedCommand.command && $0.timestamp == attachedCommand.timestamp }) {
            aiContext.attachedCommands.append(attachedCommand)
            aiContext.isAIMode = true
        }
    }
    
    private func removeCommandFromContext() {
        // Identify by command text and timestamp
        aiContext.attachedCommands.removeAll { item in
            item.command == output.text && item.timestamp == output.timestamp
        }
    }
    
    private func isOwnerAttached() -> Bool {
        return aiContext.attachedCommands.contains { item in
            item.command == output.text && item.timestamp == output.timestamp
        }
    }

    private var inlineErrorActionStrip: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(themeManager.currentTheme.errorColor)
                .frame(width: 3, height: 24)
                .cornerRadius(1.5)
            
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(themeManager.currentTheme.errorColor)
            
            Text("Command Failed")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(themeManager.currentTheme.errorColor)
            
            Spacer()
            
            // Fix with Agent button (compact single-row design)
            Button(action: {
                attachOwnerAndEnableAgent()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .medium))
                    
                    Text("Fix with Agent")
                        .font(.system(size: 11, weight: .semibold))
                    
                    HStack(spacing: 3) {
                        KeyCapInline(label: "⌘", textColor: themeManager.agentColor(), bgColor: themeManager.currentTheme.foregroundColor.opacity(0.1))
                        KeyCapInline(label: "↩", textColor: themeManager.agentColor(), bgColor: themeManager.currentTheme.foregroundColor.opacity(0.1), fontSize: 10)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(themeManager.agentColor().opacity(0.15))
            .foregroundColor(themeManager.agentColor())
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(themeManager.agentColor().opacity(0.3), lineWidth: 1)
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(themeManager.currentTheme.errorColor.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(themeManager.currentTheme.errorColor.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func attachOwnerAndEnableAgent() {
        print("🔧 [DEBUG] attachOwnerAndEnableAgent() called")
        
        // owner command for this error row
        let owner = allOutputs[ownerCommandIndex]
        print("🔧 [DEBUG] Owner command: \(owner.text)")
        
        let following = getOutputsAfterCommand(at: ownerCommandIndex, in: allOutputs)
        print("🔧 [DEBUG] Following outputs count: \(following.count)")
        
        let attached = AIAttachedCommand(from: owner, commandOutput: following)
        print("🔧 [DEBUG] Created attached command: \(attached.command)")
        
        // Clear any existing attached commands and add this one
        aiContext.attachedCommands.removeAll()
        aiContext.attachedCommands.append(attached)
        print("🔧 [DEBUG] Added command to context, total attached: \(aiContext.attachedCommands.count)")
        
        aiContext.isAIMode = true
        print("🔧 [DEBUG] AI mode enabled: \(aiContext.isAIMode)")
        
        // Put "Fix this" directly in the input field
        currentCommand = "Fix this"
        print("🔧 [DEBUG] Set currentCommand to: '\(currentCommand)'")
        
        // Focus the input field so user can start typing immediately
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("🔧 [DEBUG] Posting FocusInputField notification")
            // Trigger focus to input field
            NotificationCenter.default.post(name: NSNotification.Name("FocusInputField"), object: nil)
        }
        
        print("🔧 [DEBUG] attachOwnerAndEnableAgent() completed")
    }

    // Local keycap for inline strip
    private struct KeyCapInline: View {
        let label: String
        let textColor: Color
        let bgColor: Color
        var fontSize: CGFloat = 11
        var body: some View {
            Text(label)
                .font(.system(size: fontSize, weight: .semibold, design: .monospaced))
                .foregroundColor(textColor)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(bgColor)
                .cornerRadius(3)
        }
    }
    
    private func getOutputsAfterCommand(at commandIndex: Int, in outputs: [TerminalOutput]) -> [TerminalOutput] {
        let startIndex = commandIndex + 1
        guard startIndex < outputs.count else { return [] }
        
        var result: [TerminalOutput] = []
        
        for i in startIndex..<outputs.count {
            let output = outputs[i]
            if output.type == .command {
                break // Stop at next command
            }
            result.append(output)
        }
        
        return result
    }
    
    // Keeping helper if we want to toggle formatting later
    private func formatDirectory(_ directory: String) -> String { directory }
    
    private func colorForOutputType(_ type: TerminalOutputType) -> Color {
        switch type {
        case .command:
            return themeManager.currentTheme.foregroundColor
        case .output:
            return themeManager.currentTheme.foregroundColor.opacity(0.9)
        case .error:
            return themeManager.currentTheme.errorColor
        case .success:
            return themeManager.currentTheme.successColor
        case .aiResponse:
            return themeManager.currentTheme.foregroundColor.opacity(0.0) // Transparent since we render custom UI
        }
    }
}
