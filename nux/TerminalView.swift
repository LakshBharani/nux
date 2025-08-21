import SwiftUI

struct TerminalView: View {
    @ObservedObject var terminal: TerminalSession
    @StateObject private var commandHistory = CommandHistory()
    @StateObject private var autocomplete = AutocompleteEngine()
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var currentCommand = ""
    @State private var showSettings = false
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Terminal output area
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
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(terminal.outputs.indices, id: \.self) { index in
                                let output = terminal.outputs[index]
                                TerminalOutputRow(output: output)
                                    .environmentObject(themeManager)
                                    .id(index)
                            }
                            
                            // Add some bottom padding so last output isn't covered by control bar
                            Spacer()
                                .frame(height: 20)
                                .id("bottom-spacer")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .background(themeManager.currentTheme.backgroundColor)
                    .onChange(of: terminal.outputs.count) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo("bottom-spacer", anchor: .bottom)
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
                onExecuteCommand: executeCommand,
                onHistoryNavigation: handleHistoryNavigation
            )
            .environmentObject(themeManager)
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
        .overlay(
            // Hidden button for keyboard shortcut
            Button("Settings") {
                showSettings = true
            }
            .keyboardShortcut(",", modifiers: .command)
            .hidden()
        )
    }
    

    

    
    private func executeCommand() {
        guard !currentCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        commandHistory.addCommand(currentCommand)
        autocomplete.addToHistory(currentCommand)
        terminal.executeCommand(currentCommand)
        currentCommand = ""
        autocomplete.clearSuggestions()
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
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Show metadata above command (execution time and directory)
            if output.type == .command && (output.executionTime != nil || output.directory != nil) {
                HStack(spacing: 8) {
                    if let executionTime = output.executionTime {
                        Text("(\(String(format: "%.3f", executionTime))s)")
                            .font(.system(size: 11))
                            .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.6))
                    }
                    
                    if let directory = output.directory {
                        Text(directory)
                            .font(.system(size: 11))
                            .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.6))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Command or output content
            HStack(alignment: .top, spacing: 12) {
                if output.type == .command {
                    Text(output.prompt)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(themeManager.currentTheme.accentColor)
                }
                
                Text(output.text)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(colorForOutputType(output.type))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 2)
    }
    
    private func colorForOutputType(_ type: TerminalOutputType) -> Color {
        switch type {
        case .command:
            return themeManager.currentTheme.foregroundColor
        case .output:
            // Check if this is a divider
            if output.text == "─" {
                return themeManager.currentTheme.foregroundColor.opacity(0.3)
            }
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
