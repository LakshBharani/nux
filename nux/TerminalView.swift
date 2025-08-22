import SwiftUI

struct TerminalView: View {
    @ObservedObject var terminal: TerminalSession
    @StateObject private var commandHistory = CommandHistory()
    @StateObject private var autocomplete = AutocompleteEngine()
    @StateObject private var aiContext = AIContextManager()
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var currentCommand = ""
    @State private var showSettings = false
    @State private var shouldScrollToBottom = false
    @FocusState private var isInputFocused: Bool
    @State private var hoveredCommandIndex: Int?
    
    var body: some View {
        VStack(spacing: 0) {
            if terminal.isInVimMode {
                // Vim mode - replace entire terminal with vim editor
                VimEditor(filePath: terminal.fileToEdit) { 
                    // Exit vim mode callback
                    terminal.isInVimMode = false
                    
                    // Trigger scroll to bottom and restore focus
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        shouldScrollToBottom = true
                        isInputFocused = true
                    }
                }
                .environmentObject(themeManager)
            } else {
                // Normal terminal mode
                // Terminal output area (always show terminal, never separate AI view)
                if terminal.outputs.isEmpty {
                    TerminalEmptyStateView { suggestion in
                        currentCommand = suggestion
                        isInputFocused = true
                    }
                        .environmentObject(themeManager)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(themeManager.currentTheme.backgroundColor)
                } else {
                    ScrollViewReader { proxy in
                        GeometryReader { geo in
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 8) {
                                    ForEach(terminal.outputs.indices, id: \.self) { index in
                                        let output = terminal.outputs[index]
                                        // Determine the owning command index for this row (self for commands; nearest previous command otherwise)
                                        let ownerCommandIndex: Int = {
                                            if output.type == .command { return index }
                                            for i in stride(from: index - 1, through: 0, by: -1) {
                                                if terminal.outputs[i].type == .command { return i }
                                            }
                                            return index
                                        }()
                                        TerminalOutputRow(
                                            output: output,
                                            outputIndex: index,
                                            ownerCommandIndex: ownerCommandIndex,
                                            allOutputs: terminal.outputs,
                                            hoveredCommandIndex: $hoveredCommandIndex
                                        )
                                        .environmentObject(themeManager)
                                        .environmentObject(aiContext)
                                        .id(index)
                                    }
                                    
                                    // Anchor at bottom for scrolling
                                    Spacer().frame(height: 20).id("bottom-spacer")
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                // Key: ensure content takes at least full height and sticks to bottom
                                .frame(minHeight: geo.size.height, maxHeight: .infinity, alignment: .bottom)
                            }
                            .background(themeManager.currentTheme.backgroundColor)
                        }
                        .onChange(of: terminal.outputs.count) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo("bottom-spacer", anchor: .bottom)
                            }
                        }
                        .onChange(of: shouldScrollToBottom) {
                            if shouldScrollToBottom {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    proxy.scrollTo("bottom-spacer", anchor: .bottom)
                                }
                                shouldScrollToBottom = false
                            }
                        }
                    }
                }
                
                // Control bar at bottom
                ControlBarSimplified(
                    currentCommand: $currentCommand,
                    isInputFocused: $isInputFocused,
                    autocomplete: autocomplete,
                    terminal: terminal,
                    aiContext: aiContext,
                    onExecuteCommand: executeCommand,
                    onHistoryNavigation: handleHistoryNavigation
                )
                .environmentObject(themeManager)
            }
        }
        .background(themeManager.currentTheme.backgroundColor)
        .onAppear {
            isInputFocused = true
            terminal.startSession()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $terminal.showFileViewer) {
            FileViewer(filePath: terminal.fileToView)
                .environmentObject(themeManager)
        }
        .overlay(
            VStack {
                // Hidden buttons for keyboard shortcuts
                Button("Settings") {
                    showSettings = true
                }
                .keyboardShortcut(",", modifiers: .command)
                .hidden()
                
                Button("Agent Mode") {
                    aiContext.toggleAIMode()
                }
                .keyboardShortcut("i", modifiers: .command)
                .hidden()
                
                Button("Attach Context") {
                    aiContext.attachLatestCommand(from: terminal.outputs)
                }
                .keyboardShortcut(.upArrow, modifiers: .command)
                .hidden()
            }
        )
    }
    

    

    
    private func executeCommand() {
        guard !currentCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        if aiContext.isAIMode {
            // Execute AI prompt
            Task {
                await aiContext.executeAIPrompt(currentCommand)
            }
            currentCommand = ""
        } else {
            // Execute regular command
            commandHistory.addCommand(currentCommand)
            autocomplete.addToHistory(currentCommand)
            terminal.executeCommand(currentCommand)
            currentCommand = ""
            autocomplete.clearSuggestions()
        }
        
        isInputFocused = true
    }
    
    private func handleHistoryNavigation(_ isUp: Bool) {
        if isUp {
            if let previous = commandHistory.previousCommand() {
                currentCommand = previous
                autocomplete.clearSuggestions()
            }
        } else {
            if let next = commandHistory.nextCommand() {
                currentCommand = next
                autocomplete.clearSuggestions()
            }
        }
    }
}

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
            } else {
                // Regular output (not commands)
                Text(output.text)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(colorForOutputType(output.type))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, output.type == .command ? 0 : 2)
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
        }
    }
}

#Preview {
    TerminalView(terminal: TerminalSession())
        .frame(width: 800, height: 600)
}
