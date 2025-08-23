import SwiftUI

struct CommandInputView: View {
    @Binding var currentCommand: String
    @FocusState.Binding var isInputFocused: Bool
    @ObservedObject var autocomplete: AutocompleteEngine
    @ObservedObject var terminal: TerminalSession
    @ObservedObject var aiContext: AIContextManager
    @EnvironmentObject var themeManager: ThemeManager
    
    let onExecuteCommand: () -> Void
    let onHistoryNavigation: (Bool) -> Void
    let onGeometryChange: (CGRect, CGFloat) -> Void
    
    @State private var textFieldFrame: CGRect = .zero
    @State private var promptWidth: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 12) {
            // Prompt
            promptView
            
            // Command input with ghost text overlay
            commandInputField
        }
    }
    
    private var promptView: some View {
        Text(terminal.prompt)
            .font(.system(.body, design: .monospaced))
            .foregroundColor(themeManager.currentTheme.accentColor)
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            updatePromptWidth(geometry.size.width)
                        }
                        .onChange(of: terminal.prompt) {
                            updatePromptWidth(geometry.size.width)
                        }
                }
            )
    }
    
    private var commandInputField: some View {
        ZStack(alignment: .leading) {
            if aiContext.isProcessing {
                // Show loading animation when AI is processing
                HStack(spacing: 8) {
                    // Custom AI loading animation
                    HStack(spacing: 2) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(themeManager.agentColor())
                                .frame(width: 6, height: 6)
                                .scaleEffect(aiContext.isProcessing ? 1.0 : 0.5)
                                .animation(
                                    Animation.easeInOut(duration: 0.6)
                                        .repeatForever()
                                        .delay(Double(index) * 0.2),
                                    value: aiContext.isProcessing
                                )
                        }
                    }
                    
                    Text("Agent is thinking...")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(themeManager.agentColor().opacity(0.8))
                    
                    Spacer()
                }
            } else {
                // Ghost text (autocomplete preview) with tab button overlay
                // Always present to prevent layout shift; toggle subview opacities
                HStack(spacing: 0) {
                    Text(currentCommand)
                        .opacity(0) // Invisible, just for positioning
                    Text(autocomplete.ghostText)
                        .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.4))
                        .opacity((!autocomplete.ghostText.isEmpty && !autocomplete.showDropdown) ? 1 : 0)
                    
                    // Tab button positioned right after ghost text
                    HStack(spacing: 4) {
                        Text("⇥")
                            .font(.system(size: 10, weight: .semibold, design: .default))
                            .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.6))
                        Text("Tab")
                            .font(.system(size: 10, weight: .medium, design: .default))
                            .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.5))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(themeManager.currentTheme.backgroundColor.opacity(0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(themeManager.currentTheme.foregroundColor.opacity(0.15), lineWidth: 0.5)
                    )
                    .cornerRadius(4)
                    .padding(.leading, 8)
                    .opacity((!autocomplete.ghostText.isEmpty && !autocomplete.showDropdown && !autocomplete.allSuggestions.isEmpty) ? 1 : 0)
                    .animation(.easeOut(duration: 0.12), value: (!autocomplete.ghostText.isEmpty && !autocomplete.showDropdown && !autocomplete.allSuggestions.isEmpty))
                    .allowsHitTesting(false)
                    
                    Spacer()
                }
                .font(.system(.body, design: .monospaced))
                .allowsHitTesting(false)
                
                // Actual input field
                TextField(aiContext.isAIMode ? (aiContext.conversationHistory.isEmpty ? "Ask me anything..." : "Continue the conversation...") : "Run commands", text: $currentCommand)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(aiContext.isAIMode ? themeManager.agentColor() : themeManager.currentTheme.foregroundColor)
                    .textFieldStyle(.plain)
                    .focused($isInputFocused)
                    .accentColor(aiContext.isAIMode ? themeManager.agentColor() : themeManager.currentTheme.foregroundColor)
                    .background(
                        GeometryReader { geometry in
                            Color.clear
                                .onAppear {
                                    // Use .global coordinate space for absolute positioning
                                    updateTextFieldFrame(geometry.frame(in: .global))
                                }
                                .onChange(of: geometry.frame(in: .global)) {
                                    updateTextFieldFrame(geometry.frame(in: .global))
                                }
                                .onChange(of: currentCommand) {
                                    // Update position when text changes (cursor moves)
                                    DispatchQueue.main.async {
                                        updateTextFieldFrame(geometry.frame(in: .global))
                                        handleCommandChange()
                                    }
                                }
                        }
                    )
                    .onSubmit {
                        handleSubmit()
                    }
                    .onKeyPress(.upArrow) {
                        handleUpArrow()
                        return .handled
                    }
                    .onKeyPress(.downArrow) {
                        handleDownArrow()
                        return .handled
                    }
                    .onKeyPress { key in
                        if key.key == "c" && key.modifiers.contains(.control) {
                            handleCtrlC()
                            return .handled
                        }
                        return .ignored
                    }
                    .onKeyPress(.tab) {
                        handleTab()
                        return .handled
                    }
                    .onKeyPress(.escape) {
                        handleEscape()
                        return .handled
                    }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func updatePromptWidth(_ width: CGFloat) {
        promptWidth = width
        onGeometryChange(textFieldFrame, promptWidth)
    }
    
    private func updateTextFieldFrame(_ frame: CGRect) {
        textFieldFrame = frame
        onGeometryChange(textFieldFrame, promptWidth)
    }
    
    private func handleSubmit() {
        if autocomplete.showDropdown {
            currentCommand = autocomplete.acceptSelectedSuggestion(currentInput: currentCommand)
            autocomplete.hideDropdown()
        } else {
            onExecuteCommand()
        }
    }
    
    private func handleCommandChange() {
        autocomplete.updateInput(currentCommand, currentDirectory: terminal.currentDirectory)
    }
    
    private func handleUpArrow() {
        if autocomplete.showDropdown {
            autocomplete.navigateUp()
        } else {
            onHistoryNavigation(true)
        }
    }
    
    private func handleDownArrow() {
        if autocomplete.showDropdown {
            autocomplete.navigateDown()
        } else {
            onHistoryNavigation(false)
        }
    }
    
    private func handleTab() {
        if !autocomplete.allSuggestions.isEmpty {
            if autocomplete.showDropdown {
                autocomplete.navigateDown()
            } else {
                // If there's only one suggestion, fill it directly
                if autocomplete.allSuggestions.count == 1 {
                    currentCommand = autocomplete.acceptSelectedSuggestion(currentInput: currentCommand)
                    autocomplete.clearSuggestions()
                } else {
                    // Multiple suggestions - show dropdown
                    autocomplete.showDropdownSuggestions()
                }
            }
        }
    }
    
    private func handleEscape() {
        autocomplete.hideDropdown()
    }
    
    private func handleCtrlC() {
        // Interrupt AI execution if active
        if aiContext.isExecutingCommands || aiContext.isProcessing {
            aiContext.interruptExecution()
            
            // Clear current command to prevent accidental execution
            currentCommand = ""
            
            // Visual feedback - briefly exit AI mode to show interruption
            let previousMode = aiContext.isAIMode
            aiContext.exitAIMode()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if previousMode {
                    aiContext.enterAIMode()
                }
            }
        } else {
            // Standard Ctrl+C behavior: clear current command
            currentCommand = ""
        }
    }
}

#Preview {
    @StateObject var themeManager = ThemeManager()
    @StateObject var terminal = TerminalSession()
    @StateObject var autocomplete = AutocompleteEngine()
    @StateObject var aiContext = AIContextManager()
    @State var command = ""
    @FocusState var focused: Bool
    
    return CommandInputView(
        currentCommand: $command,
        isInputFocused: $focused,
        autocomplete: autocomplete,
        terminal: terminal,
        aiContext: aiContext,
        onExecuteCommand: { },
        onHistoryNavigation: { _ in },
        onGeometryChange: { _, _ in }
    )
    .environmentObject(themeManager)
    .padding()
}
