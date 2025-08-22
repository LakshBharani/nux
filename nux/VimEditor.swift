import SwiftUI

struct VimEditor: View {
    let filePath: String
    let onExit: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var fileContent: String = ""
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var cursorPosition: Int = 0
    @State private var mode: VimMode = .normal
    @State private var commandLine: String = ""
    @State private var showCommandLine = false
    @State private var statusMessage: String = ""
    @State private var lineNumbers: [Int] = []
    @State private var selectedRange: NSRange = NSRange(location: 0, length: 0)
    @State private var currentLine: Int = 0
    @State private var currentColumn: Int = 0
    @FocusState private var isCommandLineFocused: Bool
    @State private var undoStack: [String] = []
    @State private var redoStack: [String] = []
    @State private var lastSearch: String = ""
    @State private var searchResults: [Int] = []
    @State private var currentSearchIndex: Int = 0
    
    enum VimMode {
        case normal
        case insert
        case visual
        case command
        
        var displayName: String {
            switch self {
            case .normal: return "NORMAL"
            case .insert: return "INSERT"
            case .visual: return "VISUAL"
            case .command: return "COMMAND"
            }
        }
        
        var color: Color {
            switch self {
            case .normal: return .blue
            case .insert: return .green
            case .visual: return .orange
            case .command: return .purple
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Vim-style header
            vimHeader
            
            // Main editor area
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else {
                editorArea
            }
            
            // Vim-style status bar
            vimStatusBar
            
            // Command line (when in command mode)
            if showCommandLine {
                commandLineView
            }
        }
        .background(themeManager.currentTheme.backgroundColor)
        .onAppear {
            Task {
                await loadFile()
            }
        }
        .onKeyPress(.escape) {
            if mode == .insert {
                mode = .normal
                statusMessage = "Normal mode"
            } else if mode == .visual {
                mode = .normal
                statusMessage = "Normal mode"
            } else if showCommandLine {
                showCommandLine = false
                commandLine = ""
                mode = .normal
            }
            return .handled
        }
        .onKeyPress(.init(":")) {
            if mode == .normal {
                mode = .command
                showCommandLine = true
                commandLine = ":"
            }
            return .handled
        }
        .onKeyPress(.init("/")) {
            if mode == .normal {
                mode = .command
                showCommandLine = true
                commandLine = "/"
            }
            return .handled
        }
        .onKeyPress(.init("n")) {
            if mode == .normal && !searchResults.isEmpty {
                currentSearchIndex = (currentSearchIndex + 1) % searchResults.count
                currentLine = searchResults[currentSearchIndex]
                statusMessage = "Search result \(currentSearchIndex + 1)/\(searchResults.count)"
            }
            return .handled
        }
        .onKeyPress(.init("u")) {
            if mode == .normal && !undoStack.isEmpty {
                redoStack.append(fileContent)
                fileContent = undoStack.removeLast()
                statusMessage = "Undo"
            }
            return .handled
        }
        .onKeyPress(.init("r")) {
            if mode == .normal && !redoStack.isEmpty {
                undoStack.append(fileContent)
                fileContent = redoStack.removeLast()
                statusMessage = "Redo"
            }
            return .handled
        }
        .onKeyPress(.init("i")) {
            if mode == .normal {
                mode = .insert
                statusMessage = "Insert mode"
            }
            return .handled
        }
        .onKeyPress(.init("v")) {
            if mode == .normal {
                mode = .visual
                statusMessage = "Visual mode"
            }
            return .handled
        }
        .onKeyPress(.init("w")) {
            if mode == .normal {
                saveFile()
            }
            return .handled
        }
        .onKeyPress(.init("q")) {
            if mode == .normal {
                onExit()
            }
            return .handled
        }
        .onKeyPress(.upArrow) {
            if mode == .normal && currentLine > 0 {
                currentLine -= 1
                currentColumn = min(currentColumn, fileContent.components(separatedBy: .newlines)[currentLine].count)
            }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if mode == .normal && currentLine < fileContent.components(separatedBy: .newlines).count - 1 {
                currentLine += 1
                currentColumn = min(currentColumn, fileContent.components(separatedBy: .newlines)[currentLine].count)
            }
            return .handled
        }
        .onKeyPress(.leftArrow) {
            if mode == .normal && currentColumn > 0 {
                currentColumn -= 1
            }
            return .handled
        }
        .onKeyPress(.rightArrow) {
            if mode == .normal {
                let lines = fileContent.components(separatedBy: .newlines)
                if currentLine < lines.count && currentColumn < lines[currentLine].count {
                    currentColumn += 1
                }
            }
            return .handled
        }
    }
    
    private var vimHeader: some View {
        HStack {
            Text("VIM")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(themeManager.currentTheme.accentColor)
            
            Spacer()
            
            Text(URL(fileURLWithPath: filePath).lastPathComponent)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(themeManager.currentTheme.foregroundColor)
            
            Spacer()
            
            Text("nux")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.6))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(themeManager.currentTheme.backgroundColor.opacity(0.95))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.2)),
            alignment: .bottom
        )
    }
    
    private var loadingView: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading file...")
                .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.7))
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeManager.currentTheme.backgroundColor)
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(themeManager.currentTheme.errorColor)
            
            Text("Error Loading File")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(themeManager.currentTheme.foregroundColor)
            
            Text(error)
                .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeManager.currentTheme.backgroundColor)
    }
    
    private var editorArea: some View {
        HStack(spacing: 0) {
            // Line numbers
            lineNumbersView
            
            // Divider
            Rectangle()
                .frame(width: 1)
                .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.2))
            
            // Text content
            textContentView
        }
        .background(themeManager.currentTheme.backgroundColor)
    }
    
    private var lineNumbersView: some View {
        ScrollView {
            LazyVStack(alignment: .trailing, spacing: 0) {
                ForEach(Array(lineNumbers.enumerated()), id: \.offset) { index, lineNumber in
                    Text("\(lineNumber)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.5))
                        .frame(width: 50, height: 20, alignment: .trailing)
                        .padding(.trailing, 8)
                }
            }
        }
        .frame(width: 60)
        .background(themeManager.currentTheme.backgroundColor.opacity(0.8))
    }
    
    private var textContentView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(fileContent.components(separatedBy: .newlines).enumerated()), id: \.offset) { index, line in
                        HStack(alignment: .top, spacing: 0) {
                            Text(line.isEmpty ? " " : line)
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(themeManager.currentTheme.foregroundColor)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(
                                    mode == .visual && index == currentLine ? 
                                    themeManager.currentTheme.accentColor.opacity(0.2) : 
                                    searchResults.contains(index) ? 
                                    themeManager.currentTheme.accentColor.opacity(0.1) : 
                                    Color.clear
                                )
                                .id(index)
                            
                            // Cursor indicator
                            if index == currentLine {
                                Rectangle()
                                    .frame(width: 2, height: 18)
                                    .foregroundColor(themeManager.currentTheme.accentColor)
                                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: mode)
                                    .offset(x: CGFloat(currentColumn) * 8) // Approximate character width
                            }
                        }
                    }
                }
            }
            .background(themeManager.currentTheme.backgroundColor)
            .onChange(of: currentLine) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(currentLine, anchor: .center)
                }
            }
        }
    }
    
    private var vimStatusBar: some View {
        HStack {
            // Mode indicator
            Text(mode.displayName)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(mode.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(mode.color.opacity(0.2))
                .cornerRadius(3)
            
            // File info
            Text("\(fileContent.components(separatedBy: .newlines).count) lines")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.7))
            
            Spacer()
            
            // Status message
            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.8))
            }
            
            // Cursor position
            Text("\(currentLine + 1),\(currentColumn + 1)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(themeManager.currentTheme.backgroundColor.opacity(0.95))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.2)),
            alignment: .top
        )
    }
    
    private var commandLineView: some View {
        HStack {
            Text(":")
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(themeManager.currentTheme.accentColor)
            
            TextField("", text: $commandLine)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(themeManager.currentTheme.foregroundColor)
                .textFieldStyle(.plain)
                .focused($isCommandLineFocused)
                .onSubmit {
                    executeCommand()
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(themeManager.currentTheme.backgroundColor)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.2)),
            alignment: .top
        )
        .onAppear {
            isCommandLineFocused = true
        }
    }
    
    private func loadFile() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let url = URL(fileURLWithPath: filePath)
            let content = try String(contentsOf: url, encoding: .utf8)
            
            await MainActor.run {
                self.fileContent = content
                self.lineNumbers = Array(1...content.components(separatedBy: .newlines).count)
                self.isLoading = false
                self.statusMessage = "Type :help for commands"
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func saveFile() {
        do {
            try fileContent.write(to: URL(fileURLWithPath: filePath), atomically: true, encoding: .utf8)
            statusMessage = "File saved"
        } catch {
            statusMessage = "Error saving file: \(error.localizedDescription)"
        }
    }
    
    private func executeCommand() {
        let command = commandLine.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if command.hasPrefix("/") {
            // Search command
            let searchTerm = String(command.dropFirst())
            performSearch(searchTerm)
        } else {
            switch command {
            case "w", "write":
                saveFile()
            case "q", "quit":
                onExit()
            case "wq":
                saveFile()
                onExit()
            case "q!":
                onExit()
            case "help":
                statusMessage = "Commands: :w (save), :q (quit), :wq (save & quit), /search, n (next), u (undo), r (redo), :help (this)"
            case "h":
                statusMessage = "Commands: :w (save), :q (quit), :wq (save & quit), /search, n (next), u (undo), r (redo), :help (this)"
            default:
                if command.hasPrefix("w ") {
                    // Save as different file
                    let newPath = String(command.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
                    do {
                        try fileContent.write(to: URL(fileURLWithPath: newPath), atomically: true, encoding: .utf8)
                        statusMessage = "File saved as \(newPath)"
                    } catch {
                        statusMessage = "Error saving file: \(error.localizedDescription)"
                    }
                } else {
                    statusMessage = "Unknown command: \(command)"
                }
            }
        }
        
        showCommandLine = false
        commandLine = ""
        mode = .normal
    }
    
    private func performSearch(_ searchTerm: String) {
        guard !searchTerm.isEmpty else {
            statusMessage = "Empty search term"
            return
        }
        
        let lines = fileContent.components(separatedBy: .newlines)
        searchResults = []
        
        for (index, line) in lines.enumerated() {
            if line.localizedCaseInsensitiveContains(searchTerm) {
                searchResults.append(index)
            }
        }
        
        if !searchResults.isEmpty {
            currentSearchIndex = 0
            currentLine = searchResults[0]
            lastSearch = searchTerm
            statusMessage = "Found \(searchResults.count) matches for '\(searchTerm)'"
        } else {
            statusMessage = "No matches found for '\(searchTerm)'"
        }
    }
}

#Preview {
    VimEditor(filePath: "/tmp/test.txt", onExit: {})
        .environmentObject(ThemeManager())
}
