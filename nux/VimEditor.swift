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
    @FocusState private var isEditorFocused: Bool
    @FocusState private var isTextEditorFocused: Bool
    @State private var isVimFocused: Bool = true
    @State private var undoStack: [String] = []
    @State private var redoStack: [String] = []
    @State private var lastSearch: String = ""
    @State private var searchResults: [Int] = []
    @State private var currentSearchIndex: Int = 0
    @State private var isModified = false
    @State private var lines: [String] = []
    @State private var cursorOpacity: Double = 1.0
    @State private var scrollOffset: CGFloat = 0
    
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
        ZStack {
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
            
            // Hidden focusable area for keyboard events (no visual focus)
            Rectangle()
                .fill(Color.clear)
                .focusable()
                .focused($isEditorFocused)
        }
        .background(themeManager.currentTheme.backgroundColor)
        .focusable()
        .focusEffectDisabled()
        .onAppear {
            Task {
                await loadFile()
            }
            // Start cursor blinking immediately
            startCursorBlinking()
            // Set initial focus to vim editor
            isEditorFocused = true
        }
        .onKeyPress(.escape) {
            if mode == .insert {
                // When leaving insert mode, preserve cursor position from TextEditor
                updateCursorFromInsertMode()
                mode = .normal
                statusMessage = "Normal mode - Line \(currentLine + 1), Column \(currentColumn + 1)"
                restartCursorBlinking()
                // Return focus to vim editor for keystroke handling
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isTextEditorFocused = false
                    isEditorFocused = true
                }
            } else if mode == .visual {
                mode = .normal
                statusMessage = "Normal mode"
                restartCursorBlinking()
            } else if showCommandLine {
                showCommandLine = false
                commandLine = ""
                mode = .normal
                isCommandLineFocused = false
                statusMessage = "Normal mode"
                restartCursorBlinking()
                // Return focus to vim editor
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isEditorFocused = true
                }
            }
            return .handled
        }
        .onKeyPress(.init(":")) {
            if mode == .normal {
                mode = .command
                showCommandLine = true
                commandLine = ""
                isEditorFocused = false
                isCommandLineFocused = true
                statusMessage = "Command mode - type anything"
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.init("/")) {
            if mode == .normal {
                mode = .command
                showCommandLine = true
                commandLine = ""
                isEditorFocused = false
                isCommandLineFocused = true
                statusMessage = "Command mode - type anything"
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.init("N")) {
            if mode == .normal && !searchResults.isEmpty {
                currentSearchIndex = currentSearchIndex == 0 ? searchResults.count - 1 : currentSearchIndex - 1
                currentLine = searchResults[currentSearchIndex]
                statusMessage = "Search result \(currentSearchIndex + 1)/\(searchResults.count)"
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.init("n")) {
            if mode == .normal && !searchResults.isEmpty {
                currentSearchIndex = (currentSearchIndex + 1) % searchResults.count
                currentLine = searchResults[currentSearchIndex]
                statusMessage = "Search result \(currentSearchIndex + 1)/\(searchResults.count)"
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.init("u")) {
            if mode == .normal {
                performUndo()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.init("r")) {
            if mode == .normal {
                performRedo()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.init("i")) {
            if mode == .normal {
                addToUndoStack()
                mode = .insert
                statusMessage = "INSERT mode - Press ESC to return to normal mode"
                // Position cursor in TextEditor at current position
                setCursorPositionInTextEditor()
                // Switch focus to TextEditor
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isEditorFocused = false
                    isTextEditorFocused = true
                }
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.init("a")) {
            if mode == .normal {
                mode = .insert
                statusMessage = "Insert mode"
                // Move cursor one position to the right for 'a' command
                if currentLine < lines.count && currentColumn < lines[currentLine].count {
                    currentColumn += 1
                }
                setCursorPositionInTextEditor()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isEditorFocused = false
                    isTextEditorFocused = true
                }
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.init("A")) {
            if mode == .normal {
                mode = .insert
                statusMessage = "Insert mode"
                // Move cursor to end of line for 'A' command
                if currentLine < lines.count {
                    currentColumn = lines[currentLine].count
                }
                setCursorPositionInTextEditor()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isEditorFocused = false
                    isTextEditorFocused = true
                }
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.init("I")) {
            if mode == .normal {
                mode = .insert
                statusMessage = "Insert mode"
                // Move cursor to beginning of line for 'I' command
                currentColumn = 0
                setCursorPositionInTextEditor()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isEditorFocused = false
                    isTextEditorFocused = true
                }
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.init("o")) {
            if mode == .normal {
                insertNewLine(below: true)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.init("O")) {
            if mode == .normal {
                insertNewLine(below: false)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.init("v")) {
            if mode == .normal {
                mode = .visual
                statusMessage = "Visual mode"
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.init("w")) {
            if mode == .normal {
                // Move to next word
                moveToNextWord()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.init("W")) {
            if mode == .normal {
                // Move to next word
                if currentLine < lines.count {
                    let line = lines[currentLine]
                    let words = line.components(separatedBy: .whitespaces)
                    var currentWordIndex = 0
                    var charCount = 0
                    
                    for word in words {
                        if charCount + word.count > currentColumn {
                            break
                        }
                        charCount += word.count + 1 // +1 for space
                        currentWordIndex += 1
                    }
                    
                    if currentWordIndex < words.count {
                        currentColumn = min(charCount, line.count)
                    } else if currentLine < lines.count - 1 {
                        currentLine += 1
                        currentColumn = 0
                    }
                }
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.init("b")) {
            if mode == .normal {
                moveBackWord()
                return .handled
            }
            return .ignored
        }
        // Removed direct 'q' binding - use :q command instead
        .onKeyPress(.init("x")) {
            if mode == .normal {
                deleteCharacter()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.init("d")) {
            if mode == .normal {
                deleteLine()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.init("y")) {
            if mode == .normal {
                // Yank current line (copy to clipboard)
                if currentLine < lines.count {
                    let lineToCopy = lines[currentLine]
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(lineToCopy, forType: .string)
                    statusMessage = "Yanked line"
                }
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.init("p")) {
            if mode == .normal {
                pasteText(after: true)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.init("P")) {
            if mode == .normal {
                pasteText(after: false)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.upArrow) {
            if mode == .normal && currentLine > 0 {
                currentLine -= 1
                if currentLine < lines.count {
                    currentColumn = min(currentColumn, lines[currentLine].count)
                }
                statusMessage = "Line \(currentLine + 1), Column \(currentColumn + 1)"
                restartCursorBlinking()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.downArrow) {
            if mode == .normal {
                if currentLine < lines.count - 1 {
                    currentLine += 1
                    currentColumn = min(currentColumn, lines[currentLine].count)
                }
                statusMessage = "Line \(currentLine + 1), Column \(currentColumn + 1)"
                restartCursorBlinking()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.leftArrow) {
            if mode == .normal && currentColumn > 0 {
                currentColumn -= 1
                statusMessage = "Line \(currentLine + 1), Column \(currentColumn + 1)"
                restartCursorBlinking()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.rightArrow) {
            if mode == .normal {
                if currentLine < lines.count && currentColumn < lines[currentLine].count {
                    currentColumn += 1
                    statusMessage = "Line \(currentLine + 1), Column \(currentColumn + 1)"
                    restartCursorBlinking()
                }
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.init("0")) {
            if mode == .normal {
                currentColumn = 0
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.init("$")) {
            if mode == .normal {
                if currentLine < lines.count {
                    currentColumn = lines[currentLine].count
                }
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.init("^")) {
            if mode == .normal {
                currentColumn = 0
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.init("G")) {
            if mode == .normal {
                currentLine = lines.count - 1
                currentColumn = 0
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.init("g")) {
            if mode == .normal {
                currentLine = 0
                currentColumn = 0
                statusMessage = "Top of file - Line 1, Column 1"
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.init("h")) {
            if mode == .normal && currentColumn > 0 {
                currentColumn -= 1
                statusMessage = "Line \(currentLine + 1), Column \(currentColumn + 1)"
                restartCursorBlinking()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.init("j")) {
            if mode == .normal {
                if currentLine < lines.count - 1 {
                    currentLine += 1
                    currentColumn = min(currentColumn, lines[currentLine].count)
                }
                statusMessage = "Line \(currentLine + 1), Column \(currentColumn + 1)"
                restartCursorBlinking()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.init("k")) {
            if mode == .normal && currentLine > 0 {
                currentLine -= 1
                if currentLine < lines.count {
                    currentColumn = min(currentColumn, lines[currentLine].count)
                }
                statusMessage = "Line \(currentLine + 1), Column \(currentColumn + 1)"
                restartCursorBlinking()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.init("l")) {
            if mode == .normal {
                if currentLine < lines.count && currentColumn < lines[currentLine].count {
                    currentColumn += 1
                    statusMessage = "Line \(currentLine + 1), Column \(currentColumn + 1)"
                    restartCursorBlinking()
                }
                return .handled
            }
            return .ignored
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
        ScrollViewReader { proxy in
            ScrollView {
                HStack(spacing: 0) {
                    // Line numbers (hidden in insert mode)
                    if mode != .insert {
                        VStack(alignment: .trailing, spacing: 0) {
                            ForEach(Array(lineNumbers.enumerated()), id: \.offset) { index, lineNumber in
                                Text("\(lineNumber)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.5))
                                    .frame(width: 50, height: 20, alignment: .trailing)
                                    .padding(.trailing, 8)
                                    .id("line_\(index)")
                            }
                        }
                        .frame(width: 60)
                        .background(themeManager.currentTheme.backgroundColor.opacity(0.8))
                        
                        // Divider
                        Rectangle()
                            .frame(width: 1)
                            .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.2))
                    }
                    
                    // Text content
                    VStack(alignment: .leading, spacing: 0) {
                        if mode == .insert {
                            // Editable text area with full freedom of movement
                            TextEditor(text: $fileContent)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(themeManager.currentTheme.foregroundColor)
                                .background(themeManager.currentTheme.backgroundColor)
                                .focused($isTextEditorFocused)
                                .allowsHitTesting(true) // Enable clicking anywhere
                                .textSelection(.enabled) // Enable text selection
                                .onChange(of: fileContent) { _, newValue in
                                    isModified = true
                                    updateLines()
                                    updateLineNumbers()
                                    updateCursorFromTextEditor()
                                }
                                .onAppear {
                                    // Auto-focus TextEditor and position cursor when entering insert mode
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        isEditorFocused = false
                                        isTextEditorFocused = true
                                        // Set cursor position in TextEditor
                                        setTextEditorCursorPosition()
                                    }
                                }
                        } else {
                            // Display text with block cursor
                            ScrollViewReader { proxy in
                                ScrollView {
                                    LazyVStack(alignment: .leading, spacing: 0) {
                                        ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                                            ZStack(alignment: .topLeading) {
                                                Text(line.isEmpty ? " " : line)
                                                    .font(.system(size: 12, design: .monospaced))
                                                    .foregroundColor(themeManager.currentTheme.foregroundColor)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 2)
                                                    .frame(height: 20)
                                                    .background(
                                                        mode == .visual && index == currentLine ? 
                                                        themeManager.currentTheme.accentColor.opacity(0.2) : 
                                                        searchResults.contains(index) ? 
                                                        themeManager.currentTheme.accentColor.opacity(0.1) : 
                                                        Color.clear
                                                    )
                                                    .id("content_\(index)")
                                                
                                                // Block cursor
                                                if index == currentLine && mode == .normal {
                                                    Rectangle()
                                                        .fill(themeManager.currentTheme.accentColor)
                                                        .frame(width: 8, height: 16)
                                                        .opacity(cursorOpacity)
                                                        .offset(x: CGFloat(currentColumn) * 7.2 + 8, y: 2)
                                                        .id("cursor_\(currentLine)_\(currentColumn)")
                                                }
                                            }
                                        }
                                    }
                                }
                                .background(themeManager.currentTheme.backgroundColor)
                                .onChange(of: currentLine) {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        proxy.scrollTo("content_\(currentLine)", anchor: .center)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .background(themeManager.currentTheme.backgroundColor)
            .onChange(of: currentLine) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo("line_\(currentLine)", anchor: .center)
                    proxy.scrollTo("content_\(currentLine)", anchor: .center)
                }
            }
        }
    }
    
    private var vimStatusBar: some View {
        HStack {
            // Mode indicator
            Text(mode.displayName)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(mode.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(mode.color.opacity(0.2))
                .cornerRadius(3)
            
            // Command line display
            if showCommandLine {
                Text(commandLine)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(themeManager.currentTheme.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(themeManager.currentTheme.accentColor.opacity(0.1))
                    .cornerRadius(3)
            }
            
            // File info
            Text("\(lines.count) lines")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.7))
            
            // Modified indicator
            if isModified {
                Text("[+]")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.orange)
            }
            
            Spacer()
            
            // Status message
            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.8))
            }
            
            // Cursor position
            Text("\(currentLine + 1),\(currentColumn + 1)")
                .font(.system(size: 12, design: .monospaced))
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
            Text(commandLine.hasPrefix("/") ? "/" : commandLine.hasPrefix(":") ? ":" : ">")
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
                .onChange(of: commandLine) { _, newValue in
                    // Update status message to show current input in real-time
                    if newValue.isEmpty {
                        statusMessage = "Command mode - type anything"
                    } else if newValue.hasPrefix("/") {
                        let searchTerm = String(newValue.dropFirst())
                        if searchTerm.isEmpty {
                            statusMessage = "Search mode - type your search term"
                        } else {
                            statusMessage = "Search: \(searchTerm)"
                        }
                    } else if newValue.hasPrefix(":") {
                        let command = String(newValue.dropFirst())
                        if command.isEmpty {
                            statusMessage = "Command mode - type your command"
                        } else {
                            statusMessage = "Command: \(command)"
                        }
                    } else {
                        statusMessage = "Typing: \(newValue)"
                    }
                }
                .onAppear {
                    // Auto-focus when command line appears
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isCommandLineFocused = true
                    }
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
    }
    
    private func loadFile() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let url = URL(fileURLWithPath: filePath)
            let content = try String(contentsOf: url, encoding: .utf8)
            
            await MainActor.run {
                self.fileContent = content
                self.updateLines()
                self.updateLineNumbers()
                self.isLoading = false
                // Position cursor at first character (line 0, column 0)
                self.currentLine = 0
                self.currentColumn = 0
                self.statusMessage = "VIM mode - Line 1, Column 1 - Type :help for commands"
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func updateLines() {
        lines = fileContent.components(separatedBy: .newlines)
    }
    
    private func updateLineNumbers() {
        lineNumbers = Array(1...lines.count)
    }
    
    private func saveFile() {
        // Add to undo stack before saving
        if !undoStack.contains(fileContent) {
            undoStack.append(fileContent)
            // Keep undo stack manageable
            if undoStack.count > 50 {
                undoStack.removeFirst()
            }
        }
        
        do {
            try fileContent.write(to: URL(fileURLWithPath: filePath), atomically: true, encoding: .utf8)
            statusMessage = "File saved - \(lines.count) lines written"
            isModified = false
        } catch {
            statusMessage = "ERROR: Could not save file - \(error.localizedDescription)"
        }
    }
    
    private func moveToNextWord() {
        guard currentLine < lines.count else { return }
        
        let line = lines[currentLine]
        let startIndex = line.index(line.startIndex, offsetBy: min(currentColumn, line.count))
        
        // Find the next word boundary
        var searchIndex = startIndex
        let lineEndIndex = line.endIndex
        
        // Skip current word if we're in the middle of one
        while searchIndex < lineEndIndex && !line[searchIndex].isWhitespace {
            searchIndex = line.index(after: searchIndex)
        }
        
        // Skip whitespace
        while searchIndex < lineEndIndex && line[searchIndex].isWhitespace {
            searchIndex = line.index(after: searchIndex)
        }
        
        if searchIndex < lineEndIndex {
            // Found next word on same line
            currentColumn = line.distance(from: line.startIndex, to: searchIndex)
            statusMessage = "Line \(currentLine + 1), Column \(currentColumn + 1)"
        } else if currentLine < lines.count - 1 {
            // Move to beginning of next line
            currentLine += 1
            currentColumn = 0
            statusMessage = "Line \(currentLine + 1), Column \(currentColumn + 1)"
        } else {
            statusMessage = "End of file"
        }
    }
    
    private func moveBackWord() {
        guard currentLine < lines.count else { return }
        
        if currentColumn == 0 {
            // Move to end of previous line
            if currentLine > 0 {
                currentLine -= 1
                currentColumn = lines[currentLine].count
                statusMessage = "Line \(currentLine + 1), Column \(currentColumn + 1)"
            } else {
                statusMessage = "Beginning of file"
            }
            return
        }
        
        let line = lines[currentLine]
        let startIndex = line.index(line.startIndex, offsetBy: min(currentColumn - 1, line.count - 1))
        
        // Find the previous word boundary
        var searchIndex = startIndex
        
        // Skip current whitespace
        while searchIndex > line.startIndex && line[searchIndex].isWhitespace {
            searchIndex = line.index(before: searchIndex)
        }
        
        // Skip to beginning of current word
        while searchIndex > line.startIndex && !line[searchIndex].isWhitespace {
            searchIndex = line.index(before: searchIndex)
        }
        
        // If we stopped at whitespace, move to the next character
        if searchIndex > line.startIndex && line[searchIndex].isWhitespace {
            searchIndex = line.index(after: searchIndex)
        }
        
        currentColumn = line.distance(from: line.startIndex, to: searchIndex)
        statusMessage = "Line \(currentLine + 1), Column \(currentColumn + 1)"
    }
    
    private func performUndo() {
        guard !undoStack.isEmpty else {
            statusMessage = "Nothing to undo"
            return
        }
        
        redoStack.append(fileContent)
        fileContent = undoStack.removeLast()
        updateLines()
        updateLineNumbers()
        statusMessage = "Undo - \(undoStack.count) more changes"
        isModified = !undoStack.isEmpty // Still modified if there are more changes
        
        // Adjust cursor position if needed
        if currentLine >= lines.count {
            currentLine = max(0, lines.count - 1)
        }
        if currentLine < lines.count && currentColumn > lines[currentLine].count {
            currentColumn = lines[currentLine].count
        }
    }
    
    private func performRedo() {
        guard !redoStack.isEmpty else {
            statusMessage = "Nothing to redo"
            return
        }
        
        undoStack.append(fileContent)
        fileContent = redoStack.removeLast()
        updateLines()
        updateLineNumbers()
        statusMessage = "Redo - \(redoStack.count) more redos available"
        isModified = true
        
        // Adjust cursor position if needed
        if currentLine >= lines.count {
            currentLine = max(0, lines.count - 1)
        }
        if currentLine < lines.count && currentColumn > lines[currentLine].count {
            currentColumn = lines[currentLine].count
        }
    }
    
    private func addToUndoStack() {
        undoStack.append(fileContent)
        redoStack.removeAll() // Clear redo stack when new change is made
        
        // Keep undo stack manageable
        if undoStack.count > 50 {
            undoStack.removeFirst()
        }
    }
    
    private func deleteCharacter() {
        guard currentLine < lines.count && currentColumn < lines[currentLine].count else {
            statusMessage = "Nothing to delete"
            return
        }
        
        addToUndoStack()
        
        var line = lines[currentLine]
        line.remove(at: line.index(line.startIndex, offsetBy: currentColumn))
        lines[currentLine] = line
        fileContent = lines.joined(separator: "\n")
        isModified = true
        statusMessage = "Deleted character at column \(currentColumn + 1)"
    }
    
    private func deleteLine() {
        guard currentLine < lines.count else {
            statusMessage = "Nothing to delete"
            return
        }
        
        addToUndoStack()
        
        lines.remove(at: currentLine)
        fileContent = lines.joined(separator: "\n")
        updateLineNumbers()
        
        // Adjust cursor position
        if currentLine >= lines.count && currentLine > 0 {
            currentLine -= 1
        }
        currentColumn = 0
        isModified = true
        statusMessage = "Deleted line - \(lines.count) lines remaining"
    }
    
    private func insertNewLine(below: Bool) {
        addToUndoStack()
        
        let insertIndex = below ? currentLine + 1 : currentLine
        lines.insert("", at: insertIndex)
        fileContent = lines.joined(separator: "\n")
        updateLineNumbers()
        
        if below {
            currentLine += 1
        }
        currentColumn = 0
        isModified = true
        mode = .insert
        statusMessage = "Insert mode - new line created"
        setCursorPositionInTextEditor()
        // Switch focus to TextEditor
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isEditorFocused = false
            isTextEditorFocused = true
        }
    }
    
    private func pasteText(after: Bool) {
        guard let clipboardString = NSPasteboard.general.string(forType: .string) else {
            statusMessage = "Nothing to paste (clipboard empty)"
            return
        }
        
        guard currentLine < lines.count else {
            statusMessage = "Invalid cursor position"
            return
        }
        
        addToUndoStack()
        
        let insertIndex = after ? currentLine + 1 : currentLine
        lines.insert(clipboardString, at: insertIndex)
        fileContent = lines.joined(separator: "\n")
        updateLineNumbers()
        
        if after {
            currentLine += 1
        }
        currentColumn = 0
        isModified = true
        statusMessage = "Pasted line \(after ? "after" : "before") - \(lines.count) lines total"
    }
    
    private func executeCommand() {
        let command = commandLine.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle empty command
        guard !command.isEmpty else {
            statusMessage = "Empty input"
            closeCommandLine()
            return
        }
        
        if command.hasPrefix("/") {
            // Search command
            let searchTerm = String(command.dropFirst())
            performSearch(searchTerm)
        } else if command.hasPrefix(":") {
            // Traditional vim command (remove the : prefix)
            let cmd = String(command.dropFirst())
            executeVimCommand(cmd)
        } else {
            // Free-form input - try to interpret as a vim command
            executeVimCommand(command)
        }
        
        closeCommandLine()
    }
    
    private func executeVimCommand(_ cmd: String) {
        switch cmd {
        case "w", "write":
            saveFile()
        case "q", "quit":
            if isModified {
                statusMessage = "ERROR: No write since last change (use :q! to override or :wq to save)"
            } else {
                statusMessage = "Quitting vim editor"
                onExit()
            }
        case "wq", "x":
            saveFile()
            if !isModified { // Only quit if save was successful
                statusMessage = "File saved, quitting vim editor"
                onExit()
            }
        case "q!":
            statusMessage = "Quitting without saving"
            onExit()
        case "help", "h":
            statusMessage = "VIM COMMANDS: :w(save) :q(quit) :wq(save&quit) :q!(force quit) /search n/N(next/prev) hjkl(move) i(insert) a(append) o(new line) x(delete) d(delete line) y(yank) p(paste) u(undo) r(redo)"
        case "clear":
            searchResults = []
            currentSearchIndex = 0
            statusMessage = "Search results cleared"
        case "version", "ver":
            statusMessage = "nux vim editor v1.0 - A lightweight vim implementation"
        case "set number", "set nu":
            statusMessage = "Line numbers are always shown"
        case "set nonumber", "set nonu":
            statusMessage = "Line numbers cannot be hidden"
        default:
            if cmd.hasPrefix("w ") {
                // Save as different file
                let newPath = String(cmd.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
                if newPath.isEmpty {
                    statusMessage = "ERROR: No filename specified"
                } else {
                    saveAsFile(newPath)
                }
            } else if cmd.hasPrefix("e ") {
                // Edit different file (would need to be implemented)
                statusMessage = "ERROR: Edit command not implemented (:e filename)"
            } else if let lineNum = Int(cmd) {
                // Go to line number
                goToLine(lineNum)
            } else {
                statusMessage = "You typed: '\(cmd)' - type 'help' for available commands"
            }
        }
    }
    
    private func saveAsFile(_ path: String) {
        do {
            try fileContent.write(to: URL(fileURLWithPath: path), atomically: true, encoding: .utf8)
            statusMessage = "File saved as '\(path)' - \(lines.count) lines written"
        } catch {
            statusMessage = "ERROR: Could not save file '\(path)' - \(error.localizedDescription)"
        }
    }
    
    private func goToLine(_ lineNum: Int) {
        let targetLine = lineNum - 1 // Convert to 0-based index
        if targetLine >= 0 && targetLine < lines.count {
            currentLine = targetLine
            currentColumn = 0
            statusMessage = "Line \(lineNum), Column 1"
        } else {
            statusMessage = "ERROR: Line \(lineNum) out of range (1-\(lines.count))"
        }
    }
    
    private func closeCommandLine() {
        showCommandLine = false
        commandLine = ""
        mode = .normal
        isCommandLineFocused = false
        
        // Restart cursor blinking in normal mode
        restartCursorBlinking()
        
        // Return focus to vim editor for keystroke handling
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isEditorFocused = true
        }
    }
    
    private func startCursorBlinking() {
        cursorOpacity = 1.0
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            cursorOpacity = 0.0
        }
    }
    
    private func restartCursorBlinking() {
        // Stop current animation and restart
        cursorOpacity = 1.0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                cursorOpacity = 0.0
            }
        }
    }
    
    private func setCursorPositionInTextEditor() {
        // Calculate text position up to current cursor position
        var textPosition = 0
        for i in 0..<currentLine {
            if i < lines.count {
                textPosition += lines[i].count + 1 // +1 for newline
            }
        }
        // Add column position, but ensure we don't exceed line length
        if currentLine < lines.count {
            textPosition += min(currentColumn, lines[currentLine].count)
        } else {
            textPosition += currentColumn
        }
        
        // Store the position for TextEditor
        cursorPosition = textPosition
        selectedRange = NSRange(location: textPosition, length: 0)
        
        // Update status to show exact position
        statusMessage = "Insert mode at Line \(currentLine + 1), Column \(currentColumn + 1)"
    }
    
    private func setTextEditorCursorPosition() {
        // Calculate the exact text position for cursor placement
        var textPosition = 0
        
        // Count characters up to current line
        for i in 0..<currentLine {
            if i < lines.count {
                textPosition += lines[i].count + 1 // +1 for newline
            }
        }
        
        // Add column position within current line
        if currentLine < lines.count {
            textPosition += min(currentColumn, lines[currentLine].count)
        } else {
            textPosition += currentColumn
        }
        
        // Store position for potential use
        cursorPosition = textPosition
        selectedRange = NSRange(location: textPosition, length: 0)
        
        // Provide visual feedback
        statusMessage = "Editing at Line \(currentLine + 1), Column \(currentColumn + 1)"
    }
    
    private func updateCursorFromTextEditor() {
        // Update currentLine and currentColumn based on text changes
        // Calculate position from content length and structure
        let allText = fileContent
        let currentLines = allText.components(separatedBy: .newlines)
        
        // If content changed significantly, try to maintain relative position
        if currentLines.count != lines.count {
            // Content structure changed, adjust cursor position
            if currentLine >= currentLines.count {
                currentLine = max(0, currentLines.count - 1)
            }
            if currentLine < currentLines.count && currentColumn > currentLines[currentLine].count {
                currentColumn = currentLines[currentLine].count
            }
        }
        
        // Update status with current position
        statusMessage = "Line \(currentLine + 1), Column \(currentColumn + 1) - \(currentLines.count) lines"
    }
    
    private func updateCursorFromInsertMode() {
        // Try to determine cursor position when leaving insert mode
        // This function attempts to track where the user was typing
        let allText = fileContent
        let currentLines = allText.components(separatedBy: .newlines)
        
        // Ensure our tracked position is valid
        if currentLine >= currentLines.count {
            currentLine = max(0, currentLines.count - 1)
        }
        
        if currentLine < currentLines.count {
            // Make sure column position is within line bounds
            let lineLength = currentLines[currentLine].count
            if currentColumn > lineLength {
                currentColumn = lineLength
            }
        }
        
        // Provide feedback about the position
        statusMessage = "Cursor positioned at Line \(currentLine + 1), Column \(currentColumn + 1)"
    }
    
    private func performSearch(_ searchTerm: String) {
        guard !searchTerm.isEmpty else {
            statusMessage = "Empty search term"
            return
        }
        
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
