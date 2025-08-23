import SwiftUI
import AppKit

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
                                            hoveredCommandIndex: $hoveredCommandIndex,
                                            currentCommand: $currentCommand
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
                        .onChange(of: aiContext.conversationHistory.count) {
                            // Always scroll to bottom when AI responses are added
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
            
            // Set terminal session reference in AI context manager
            aiContext.terminalSession = terminal
            
            // Listen for focus input field notifications
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("FocusInputField"),
                object: nil,
                queue: .main
            ) { _ in
                isInputFocused = true
            }
            

            
            // Listen for approve risky command notifications
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ApproveRiskyCommand"),
                object: nil,
                queue: .main
            ) { notification in
                if let command = notification.object as? String {
                    // Approve and execute the risky command
                    Task {
                        await aiContext.approveRiskyCommand(command)
                    }
                }
            }
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

                // Command+Enter handler — Fix with Agent
                Button("Command+Enter Handler") {
                    // Since commands are now executed autonomously, this shortcut is for "Fix with Agent"
                    if let lastCommandIndex = findLastCommandIndex(in: terminal.outputs) {
                        let lastCommand = terminal.outputs[lastCommandIndex]
                        let following = getOutputsAfterCommand(at: lastCommandIndex, in: terminal.outputs)
                        let attached = AIAttachedCommand(from: lastCommand, commandOutput: following)
                        
                        // Clear any existing attached commands and add this one
                        aiContext.attachedCommands.removeAll()
                        aiContext.attachedCommands.append(attached)
                        
                        aiContext.isAIMode = true
                        currentCommand = "Fix this"
                    }
                    isInputFocused = true
                }
                .keyboardShortcut(.return, modifiers: .command)
                .hidden()
            }
        )
    }
    
    private func executeCommand() {
        guard !currentCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { 
            return 
        }
        
        if aiContext.isAIMode {
            let promptToSend = currentCommand
            currentCommand = ""
            // Execute AI prompt
            Task {
                await aiContext.executeAIPrompt(promptToSend)
            }
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
    
    // Helper functions for the ⌘↩ shortcut
    private func findLastCommandIndex(in outputs: [TerminalOutput]) -> Int? {
        for i in (0..<outputs.count).reversed() {
            if outputs[i].type == .command {
                return i
            }
        }
        return nil
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
}

#Preview {
    TerminalView(terminal: TerminalSession())
        .frame(width: 800, height: 600)
}
