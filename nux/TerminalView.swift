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
                    GeometryReader { geo in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 8) {
                                ForEach(terminal.outputs.indices, id: \.self) { index in
                                    let output = terminal.outputs[index]
                                    TerminalOutputRow(output: output)
                                        .environmentObject(themeManager)
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
            if output.type == .command {
                // Divider above each command - full width
                Divider()
                    .background(themeManager.currentTheme.foregroundColor.opacity(0.1))
                    .padding(.vertical, 8)
                // Show directory and execution time above command
                if let directory = output.directory, let executionTime = output.executionTime {
                    HStack {
                        Text(formatDirectory(directory))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.6))
                        
                        Text("(\(String(format: "%.3fs", executionTime)))")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.6))
                        
                        Spacer()
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
    }
    
    private func formatDirectory(_ directory: String) -> String {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
        if directory.hasPrefix(homeDirectory) {
            return directory.replacingOccurrences(of: homeDirectory, with: "~")
        }
        return directory
    }
    
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
