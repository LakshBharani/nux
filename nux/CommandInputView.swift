import SwiftUI

struct CommandInputView: View {
    @Binding var currentCommand: String
    @FocusState.Binding var isInputFocused: Bool
    @ObservedObject var autocomplete: AutocompleteEngine
    @ObservedObject var terminal: TerminalSession
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
            // Ghost text (autocomplete preview) - only show when dropdown is not visible
            if !autocomplete.ghostText.isEmpty && !autocomplete.showDropdown {
                HStack(spacing: 0) {
                    Text(currentCommand)
                        .opacity(0) // Invisible, just for positioning
                    Text(autocomplete.ghostText)
                        .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.4))
                    Spacer()
                }
                .font(.system(.body, design: .monospaced))
            }
            
            // Actual input field
            TextField("Run a command...", text: $currentCommand)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(themeManager.currentTheme.foregroundColor)
                .textFieldStyle(.plain)
                .focused($isInputFocused)
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
                .onKeyPress(.tab) {
                    handleTab()
                    return .handled
                }
                .onKeyPress(.escape) {
                    handleEscape()
                    return .handled
                }
        }
        .overlay(alignment: .trailing) {
            // Tab hint to indicate activating autocomplete popup
            if !autocomplete.allSuggestions.isEmpty && !autocomplete.showDropdown {
                HStack(spacing: 6) {
                    Text("⇥")
                        .font(.system(size: 11, weight: .semibold, design: .default))
                        .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.75))
                    Text("Tab")
                        .font(.system(size: 11, weight: .medium, design: .default))
                        .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.55))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(themeManager.currentTheme.backgroundColor.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(themeManager.currentTheme.foregroundColor.opacity(0.2), lineWidth: 1)
                )
                .cornerRadius(6)
                .padding(.trailing, 2)
                .allowsHitTesting(false)
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
            currentCommand = autocomplete.acceptSelectedSuggestion()
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
                autocomplete.showDropdownSuggestions()
            }
        }
    }
    
    private func handleEscape() {
        autocomplete.hideDropdown()
    }
}

#Preview {
    @Previewable @StateObject var themeManager = ThemeManager()
    @Previewable @StateObject var terminal = TerminalSession()
    @Previewable @StateObject var autocomplete = AutocompleteEngine()
    @Previewable @State var command = ""
    @Previewable @FocusState var focused: Bool
    
    return CommandInputView(
        currentCommand: $command,
        isInputFocused: $focused,
        autocomplete: autocomplete,
        terminal: terminal,
        onExecuteCommand: { },
        onHistoryNavigation: { _ in },
        onGeometryChange: { _, _ in }
    )
    .environmentObject(themeManager)
    .padding()
}
