import SwiftUI

// Helper struct for AI response sections
struct AISection {
    let title: String
    let content: String
    let icon: String
    let color: Color
}

struct AIResponseViews {
    static func inlineAIResponseView(response: AIConversationEntry, themeManager: ThemeManager) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with connection line
            HStack(spacing: 8) {
                Rectangle()
                    .fill(themeManager.agentColor())
                    .frame(width: 3, height: 24)
                    .cornerRadius(1.5)
                
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(themeManager.agentColor())
                    
                    Text("Agent Assist")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(themeManager.agentColor())
                    
                    Spacer()
                    
                    Text(response.timestamp, style: .time)
                        .font(.system(size: 10))
                        .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.6))
                }
            }
            
            // User prompt card with proper alignment
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(themeManager.currentTheme.accentColor)
                    .frame(width: 20, height: 20)
                
                VStack(alignment: .leading, spacing: 0) {
                    Text(response.prompt)
                        .font(.system(size: 12))
                        .foregroundColor(themeManager.currentTheme.foregroundColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
                .background(themeManager.currentTheme.accentColor.opacity(0.1))
                .cornerRadius(8)
            }
            
            // AI explanation card with better structure and alignment
            if !response.response.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 16))
                            .foregroundColor(themeManager.agentColor())
                            .frame(width: 20, height: 20)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            // Parse and structure the AI response
                            let sections = parseAIResponse(response.response)
                            
                            ForEach(sections, id: \.title) { section in
                                VStack(alignment: .leading, spacing: 6) {
                                    if !section.title.isEmpty {
                                        HStack(spacing: 6) {
                                            Image(systemName: section.icon)
                                                .font(.system(size: 11))
                                                .foregroundColor(section.color)
                                            
                                            Text(section.title)
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundColor(section.color)
                                        }
                                    }
                                    
                                    Text(section.content)
                                        .font(.system(size: 11))
                                        .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.9))
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(10)
                                .background(section.color.opacity(0.08))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(section.color.opacity(0.2), lineWidth: 1)
                                )
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            
            // AI Command Execution Section with proper alignment
            if !response.executedCommands.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "cpu.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.purple)
                            .frame(width: 20, height: 20)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("AI Executed Commands:")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.purple)
                                
                                Spacer()
                                
                                Text("\(response.executedCommands.count) command\(response.executedCommands.count == 1 ? "" : "s")")
                                    .font(.system(size: 10))
                                    .foregroundColor(.purple.opacity(0.7))
                            }
                            
                            ForEach(response.executedCommands) { execCommand in
                                AIExecutedCommandView(command: execCommand, themeManager: themeManager)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            
            // Pending risky command approval
            if let pendingCommand = response.pendingRiskyCommand {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                        
                        Text("Risky Command - Approval Required:")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.red)
                        
                        Spacer()
                        
                        Button(action: {
                            // Post notification to approve risky command
                            NotificationCenter.default.post(
                                name: NSNotification.Name("ApproveRiskyCommand"),
                                object: pendingCommand
                            )
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.shield.fill")
                                    .font(.system(size: 10))
                                Text("Approve & Run")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.red.opacity(0.2))
                            .foregroundColor(.red)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Text(pendingCommand)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(themeManager.currentTheme.foregroundColor)
                        .padding(10)
                        .background(.red.opacity(0.1))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.red.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            
            // Context information card with proper alignment
            if !response.attachedCommands.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "paperclip")
                            .font(.system(size: 16))
                            .foregroundColor(themeManager.currentTheme.accentColor)
                            .frame(width: 20, height: 20)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Context:")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(themeManager.currentTheme.accentColor)
                            
                            ForEach(response.attachedCommands.prefix(2)) { command in
                                HStack(spacing: 8) {
                                    Image(systemName: "terminal")
                                        .font(.system(size: 12))
                                        .foregroundColor(command.isError ? themeManager.currentTheme.errorColor : themeManager.currentTheme.accentColor)
                                    
                                    Text(command.command)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.8))
                                        .lineLimit(1)
                                    
                                    if command.isError {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.system(size: 10))
                                            .foregroundColor(themeManager.currentTheme.errorColor)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(10)
                                .background(themeManager.currentTheme.foregroundColor.opacity(0.05))
                                .cornerRadius(8)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(12)
        .background(themeManager.agentColor().opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(themeManager.agentColor().opacity(0.2), lineWidth: 1)
        )
        .shadow(color: themeManager.agentColor().opacity(0.1), radius: 1, x: 0, y: 0.5)
    }
    
    static func generalAIResponseView(response: AIConversationEntry, themeManager: ThemeManager) -> some View {
        // Use the same structure as inlineAIResponseView but without the connection line
        VStack(alignment: .leading, spacing: 12) {
            // Header (same as inline but without connection line)
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(themeManager.agentColor())
                
                Text("Agent Assist")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(themeManager.agentColor())
                
                Spacer()
                
                Text(response.timestamp, style: .time)
                    .font(.system(size: 10))
                    .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.6))
            }
            
            // User prompt card with proper alignment (same as inline)
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(themeManager.currentTheme.accentColor)
                    .frame(width: 20, height: 20)
                
                VStack(alignment: .leading, spacing: 0) {
                    Text(response.prompt)
                        .font(.system(size: 12))
                        .foregroundColor(themeManager.currentTheme.foregroundColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
                .background(themeManager.currentTheme.accentColor.opacity(0.1))
                .cornerRadius(8)
            }
            
            // AI explanation card with better structure and alignment (same as inline)
            if !response.response.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 16))
                            .foregroundColor(themeManager.agentColor())
                            .frame(width: 20, height: 20)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            // Parse and structure the AI response
                            let sections = parseAIResponse(response.response)
                            
                            ForEach(sections, id: \.title) { section in
                                VStack(alignment: .leading, spacing: 6) {
                                    if !section.title.isEmpty {
                                        HStack(spacing: 6) {
                                            Image(systemName: section.icon)
                                                .font(.system(size: 11))
                                                .foregroundColor(section.color)
                                            
                                            Text(section.title)
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundColor(section.color)
                                        }
                                    }
                                    
                                    Text(section.content)
                                        .font(.system(size: 11))
                                        .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.9))
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(10)
                                .background(section.color.opacity(0.08))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(section.color.opacity(0.2), lineWidth: 1)
                                )
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            
            // AI Command Execution Section with proper alignment (same as inline)
            if !response.executedCommands.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "cpu.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.purple)
                            .frame(width: 20, height: 20)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("AI Executed Commands:")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.purple)
                                
                                Spacer()
                                
                                Text("\(response.executedCommands.count) command\(response.executedCommands.count == 1 ? "" : "s")")
                                    .font(.system(size: 10))
                                    .foregroundColor(.purple.opacity(0.7))
                            }
                            
                            ForEach(response.executedCommands) { execCommand in
                                AIExecutedCommandView(command: execCommand, themeManager: themeManager)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            
            // Pending risky command approval (same as inline)
            if let pendingCommand = response.pendingRiskyCommand {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                        
                        Text("Risky Command - Approval Required:")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.red)
                        
                        Spacer()
                        
                        Button(action: {
                            // Post notification to approve risky command
                            NotificationCenter.default.post(
                                name: NSNotification.Name("ApproveRiskyCommand"),
                                object: pendingCommand
                            )
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.shield.fill")
                                    .font(.system(size: 10))
                                Text("Approve & Run")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.red.opacity(0.2))
                            .foregroundColor(.red)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Text(pendingCommand)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(themeManager.currentTheme.foregroundColor)
                        .padding(10)
                        .background(.red.opacity(0.1))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.red.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            
            // Context information card with proper alignment (same as inline)
            if !response.attachedCommands.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "paperclip")
                            .font(.system(size: 16))
                            .foregroundColor(themeManager.currentTheme.accentColor)
                            .frame(width: 20, height: 20)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Context:")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(themeManager.currentTheme.accentColor)
                            
                            ForEach(response.attachedCommands.prefix(2)) { command in
                                HStack(spacing: 8) {
                                    Image(systemName: "terminal")
                                        .font(.system(size: 12))
                                        .foregroundColor(command.isError ? themeManager.currentTheme.errorColor : themeManager.currentTheme.accentColor)
                                    
                                    Text(command.command)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.8))
                                        .lineLimit(1)
                                    
                                    if command.isError {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.system(size: 10))
                                            .foregroundColor(themeManager.currentTheme.errorColor)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(10)
                                .background(themeManager.currentTheme.foregroundColor.opacity(0.05))
                                .cornerRadius(8)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(12)
        .background(themeManager.agentColor().opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(themeManager.agentColor().opacity(0.2), lineWidth: 1)
        )
        .shadow(color: themeManager.agentColor().opacity(0.1), radius: 1, x: 0, y: 0.5)
    }
    
    // Helper function to parse AI response into structured sections
    static func parseAIResponse(_ response: String) -> [AISection] {
        var sections: [AISection] = []
        
        // Remove ConfirmRequired text
        let cleanedResponse = response.replacingOccurrences(of: "ConfirmRequired: no", with: "")
            .replacingOccurrences(of: "ConfirmRequired: yes", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Split by common section markers
        let lines = cleanedResponse.components(separatedBy: .newlines)
        var currentSection = ""
        var currentContent = ""
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine.isEmpty { continue }
            
            // Check for section headers
            if trimmedLine.hasSuffix(":") && !trimmedLine.contains(" ") {
                // Save previous section
                if !currentContent.isEmpty {
                    sections.append(createSection(title: currentSection, content: currentContent.trimmingCharacters(in: .whitespacesAndNewlines)))
                }
                
                currentSection = String(trimmedLine.dropLast()) // Remove the colon
                currentContent = ""
            } else {
                if currentContent.isEmpty {
                    currentContent = trimmedLine
                } else {
                    currentContent += "\n" + trimmedLine
                }
            }
        }
        
        // Add the last section
        if !currentContent.isEmpty {
            sections.append(createSection(title: currentSection, content: currentContent.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        
        // If no sections were found, treat the entire response as one section
        if sections.isEmpty {
            sections.append(createSection(title: "", content: cleanedResponse))
        }
        
        return sections
    }
    
    private static func createSection(title: String, content: String) -> AISection {
        let lowerTitle = title.lowercased()
        
        switch lowerTitle {
        case "suggested", "suggestion":
            return AISection(title: title, content: content, icon: "lightbulb.fill", color: .orange)
        case "notes", "note":
            return AISection(title: title, content: content, icon: "note.text", color: .blue)
        case "risk", "warning":
            return AISection(title: title, content: content, icon: "exclamationmark.triangle.fill", color: .red)
        case "explanation", "analysis":
            return AISection(title: title, content: content, icon: "brain.head.profile", color: .purple)
        default:
            return AISection(title: title, content: content, icon: "info.circle", color: .gray)
        }
    }
}

// MARK: - Executed Command View
struct AIExecutedCommandView: View {
    let command: AIExecutedCommand
    let themeManager: ThemeManager
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Command header with expand/collapse
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.purple)
                    
                    Image(systemName: command.wasAutoExecuted ? "cpu" : "hand.raised.fill")
                        .font(.system(size: 10))
                        .foregroundColor(command.wasAutoExecuted ? .purple : .orange)
                    
                    Text(command.command)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(themeManager.currentTheme.foregroundColor)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if command.error != nil {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.red)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.green)
                    }
                    
                    Text(command.timestamp, style: .time)
                        .font(.system(size: 9))
                        .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.6))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.purple.opacity(0.1))
            .cornerRadius(6)
            
            // Expandable output section
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    // Command output
                    if !command.output.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "text.line.first.and.arrowtriangle.forward")
                                    .font(.system(size: 9))
                                    .foregroundColor(.green)
                                Text("Output:")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.green)
                            }
                            
                            Text(command.output)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.9))
                                .padding(8)
                                .background(.green.opacity(0.05))
                                .cornerRadius(4)
                        }
                    }
                    
                    // Command error
                    if let error = command.error {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(.red)
                                Text("Error:")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.red)
                            }
                            
                            Text(error)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.red)
                                .padding(8)
                                .background(.red.opacity(0.05))
                                .cornerRadius(4)
                        }
                    }
                    
                    // Command metadata
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "folder")
                                .font(.system(size: 8))
                                .foregroundColor(themeManager.currentTheme.accentColor)
                            Text(command.directory)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.7))
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: command.isRisky ? "exclamationmark.shield" : "checkmark.shield")
                                .font(.system(size: 8))
                                .foregroundColor(command.isRisky ? .red : .green)
                            Text(command.isRisky ? "Risky" : "Safe")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(command.isRisky ? .red : .green)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
        }
        .background(themeManager.currentTheme.foregroundColor.opacity(0.02))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.purple.opacity(0.2), lineWidth: 1)
        )
    }
}
