import SwiftUI
import AppKit

struct VimShellView: View {
    let currentDirectory: String
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    
    @State private var files: [FileItem] = []
    @State private var isLoading = true
    @State private var mode: VimMode = .normal
    @State private var commandLine: String = ""
    @State private var showCommandLine = false
    @State private var statusMessage: String = ""
    @State private var selectedIndex: Int = 0
    @State private var searchTerm: String = ""
    @State private var filteredFiles: [FileItem] = []
    @FocusState private var isCommandLineFocused: Bool
    
    struct FileItem: Identifiable {
        let id = UUID()
        let name: String
        let path: String
        let isDirectory: Bool
        let size: String?
        let modifiedDate: Date?
        
        var icon: String {
            if isDirectory {
                return "folder.fill"
            } else {
                let ext = URL(fileURLWithPath: name).pathExtension.lowercased()
                switch ext {
                case "pdf": return "doc.richtext"
                case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "svg", "webp": return "photo"
                case "mp4", "mov", "avi", "mkv": return "video"
                case "mp3", "wav", "aac", "flac": return "music.note"
                case "txt", "md", "json", "xml", "html", "css", "js", "py", "swift", "java", "c", "cpp", "h", "hpp", "sh", "zsh", "bash", "yaml", "yml", "toml", "ini", "conf", "log": return "doc.text"
                default: return "doc"
                }
            }
        }
    }
    
    enum VimMode {
        case normal
        case command
        
        var displayName: String {
            switch self {
            case .normal: return "NORMAL"
            case .command: return "COMMAND"
            }
        }
        
        var color: Color {
            switch self {
            case .normal: return .blue
            case .command: return .purple
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Vim-style header
            vimHeader
            
            // Main content area
            if isLoading {
                loadingView
            } else {
                fileListArea
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
                await loadFiles()
            }
        }
        .onKeyPress(.escape) {
            if showCommandLine {
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
        .onKeyPress(.upArrow) {
            if mode == .normal && selectedIndex > 0 {
                selectedIndex -= 1
            }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if mode == .normal && selectedIndex < filteredFiles.count - 1 {
                selectedIndex += 1
            }
            return .handled
        }
        .onKeyPress(.return) {
            if mode == .normal && !filteredFiles.isEmpty {
                openSelectedFile()
            }
            return .handled
        }
        .onKeyPress(.space) {
            if mode == .normal && !filteredFiles.isEmpty {
                openSelectedFile()
            }
            return .handled
        }
        .onKeyPress(.init("q")) {
            if mode == .normal {
                dismiss()
            }
            return .handled
        }
    }
    
    private var vimHeader: some View {
        HStack {
            Text("VIM SHELL")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(themeManager.currentTheme.accentColor)
            
            Spacer()
            
            Text(URL(fileURLWithPath: currentDirectory).lastPathComponent)
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
            Text("Loading files...")
                .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.7))
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeManager.currentTheme.backgroundColor)
    }
    
    private var fileListArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(filteredFiles.enumerated()), id: \.offset) { index, file in
                        HStack(spacing: 12) {
                            Image(systemName: file.icon)
                                .foregroundColor(file.isDirectory ? themeManager.currentTheme.accentColor : themeManager.currentTheme.foregroundColor.opacity(0.8))
                                .font(.system(size: 16))
                                .frame(width: 20)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(file.name)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(themeManager.currentTheme.foregroundColor)
                                
                                if let size = file.size {
                                    Text(size)
                                        .font(.system(size: 11))
                                        .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.6))
                                }
                            }
                            
                            Spacer()
                            
                            if let date = file.modifiedDate {
                                Text(formatDate(date))
                                    .font(.system(size: 11))
                                    .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.6))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            index == selectedIndex ? 
                            themeManager.currentTheme.accentColor.opacity(0.2) : 
                            Color.clear
                        )
                        .id(index)
                    }
                }
            }
            .background(themeManager.currentTheme.backgroundColor)
            .onChange(of: selectedIndex) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(selectedIndex, anchor: .center)
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
            Text("\(filteredFiles.count) files")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.7))
            
            Spacer()
            
            // Status message
            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.8))
            }
            
            // Selection info
            if !filteredFiles.isEmpty {
                Text("\(selectedIndex + 1)/\(filteredFiles.count)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.7))
            }
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
            Text(commandLine.hasPrefix("/") ? "/" : ":")
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
    
    private func loadFiles() async {
        isLoading = true
        
        do {
            let fileManager = FileManager.default
            let contents = try fileManager.contentsOfDirectory(atPath: currentDirectory)
            
            var fileItems: [FileItem] = []
            
            for item in contents {
                let fullPath = URL(fileURLWithPath: currentDirectory).appendingPathComponent(item).path
                
                var isDirectory: ObjCBool = false
                let exists = fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory)
                
                if exists {
                    let attributes = try? fileManager.attributesOfItem(atPath: fullPath)
                    let size = attributes?[.size] as? Int64
                    let modifiedDate = attributes?[.modificationDate] as? Date
                    
                    let sizeString = size != nil ? formatFileSize(size!) : nil
                    
                    let fileItem = FileItem(
                        name: item,
                        path: fullPath,
                        isDirectory: isDirectory.boolValue,
                        size: sizeString,
                        modifiedDate: modifiedDate
                    )
                    
                    fileItems.append(fileItem)
                }
            }
            
            // Sort: directories first, then files, both alphabetically
            fileItems.sort { item1, item2 in
                if item1.isDirectory != item2.isDirectory {
                    return item1.isDirectory
                }
                return item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedAscending
            }
            
            await MainActor.run {
                self.files = fileItems
                self.filteredFiles = fileItems
                self.isLoading = false
                self.statusMessage = "Type :help for commands"
            }
        } catch {
            await MainActor.run {
                self.files = []
                self.filteredFiles = []
                self.isLoading = false
            }
        }
    }
    
    private func openSelectedFile() {
        guard selectedIndex < filteredFiles.count else { return }
        
        let selectedFile = filteredFiles[selectedIndex]
        
        if selectedFile.isDirectory {
            // Navigate to directory
            // This would require updating the current directory
            statusMessage = "Directory navigation not implemented yet"
        } else {
            // Open file
            let fileType = FileViewer.FileType.determine(for: selectedFile.path)
            
            if fileType == .text {
                // Open in VimEditor
                // This would require a callback to the parent view
                statusMessage = "Opening \(selectedFile.name) in editor"
            } else {
                // Open with system app
                let url = URL(fileURLWithPath: selectedFile.path)
                if NSWorkspace.shared.open(url) {
                    statusMessage = "Opened \(selectedFile.name) with system app"
                } else {
                    statusMessage = "Error opening \(selectedFile.name)"
                }
            }
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
            case "q", "quit":
                dismiss()
            case "help":
                statusMessage = "Commands: :q (quit), /search, ↑↓ (navigate), Enter (open), :help (this)"
            case "h":
                statusMessage = "Commands: :q (quit), /search, ↑↓ (navigate), Enter (open), :help (this)"
            default:
                statusMessage = "Unknown command: \(command)"
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
        
        filteredFiles = files.filter { $0.name.localizedCaseInsensitiveContains(searchTerm) }
        selectedIndex = 0
        
        if !filteredFiles.isEmpty {
            statusMessage = "Found \(filteredFiles.count) matches for '\(searchTerm)'"
        } else {
            statusMessage = "No matches found for '\(searchTerm)'"
        }
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    VimShellView(currentDirectory: "/tmp")
        .environmentObject(ThemeManager())
}
