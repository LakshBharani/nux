import SwiftUI
import AppKit

// MARK: - Focus Management
enum FocusTarget {
    case input
    case directoryPopup
    case none
}

struct ControlBarSimplified: View {
    @Binding var currentCommand: String
    @FocusState.Binding var isInputFocused: Bool
    @ObservedObject var autocomplete: AutocompleteEngine
    @ObservedObject var terminal: TerminalSession
    @EnvironmentObject var themeManager: ThemeManager
    
    let onExecuteCommand: () -> Void
    let onHistoryNavigation: (Bool) -> Void // true for up, false for down
    
    @State private var fileContext: FileContext?
    @State private var textFieldFrame: CGRect = .zero
    @State private var promptWidth: CGFloat = 0
    @State private var showDirectoryBrowser = false
    @State private var showFileBrowser = false
    @State private var directoryItems: [PopupItem] = []
    @State private var selectedDirectoryIndex: Int = 0
    
    // MARK: - Focus Management
    @State private var currentFocus: FocusTarget = .input
    @FocusState private var isDirectoryPopupFocused: Bool
    
    var body: some View {
        mainContent
            .onAppear {
                updateFileContext()
                // Ensure input has focus on startup
                if currentFocus == .input && !isInputFocused {
                    updateFocusStates()
                }
            }
            .onChange(of: terminal.currentDirectory) {
                updateFileContext()
            }
            .onChange(of: currentFocus) {
                updateFocusStates()
            }
            .onChange(of: autocomplete.showDropdown) {
                handleAutocompleteVisibilityChange()
            }
            .overlay(autocompletePopupOverlay)
            .overlay(directoryBrowserOverlay)
            .sheet(isPresented: $showFileBrowser) {
                FileBrowser(
                    currentDirectory: terminal.currentDirectory,
                    onFileSelected: { filePath in
                        // Open the selected file
                        terminal.fileToView = filePath
                        terminal.showFileViewer = true
                    }
                )
                .environmentObject(themeManager)
            }
    }
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                // Top line: Directory info with current directory
                HStack(spacing: 12) {
                    // Current directory path (clickable)
                    if let context = fileContext {
                        Button(action: {
                            openDirectoryBrowser()
                        }) {
                            HStack(spacing: 6) {
                                Text("in")
                                    .font(.system(size: 12))
                                    .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.5))
                                
                                Text(formatDirectoryPath(context.currentDirectory))
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .foregroundColor(themeManager.currentTheme.accentColor)
                                
                                Image(systemName: "chevron.up")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.5))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(themeManager.currentTheme.accentColor.opacity(0.1))
                            .cornerRadius(4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        // Folder icon with file count and size (clickable)
                        Button(action: {
                            openDirectoryBrowser()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "folder.fill")
                                    .foregroundColor(themeManager.currentTheme.accentColor.opacity(0.8))
                                    .font(.system(size: 13))
                                
                                Text(context.summary)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.6))
                                
                                if let size = context.totalSize, size != "Zero KB" {
                                    Text("•")
                                        .font(.system(size: 8))
                                        .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.3))
                                    
                                    Text(size)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.6))
                                }
                                
                                Image(systemName: "chevron.up")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.4))
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Bottom line: Command input
                HStack(spacing: 12) {
                    CommandInputView(
                        currentCommand: $currentCommand,
                        isInputFocused: $isInputFocused,
                        autocomplete: autocomplete,
                        terminal: terminal,
                        onExecuteCommand: onExecuteCommand,
                        onHistoryNavigation: onHistoryNavigation,
                        onGeometryChange: handleGeometryChange
                    )
                    .environmentObject(themeManager)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(themeManager.currentTheme.backgroundColor.opacity(0.95))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(themeManager.currentTheme.foregroundColor.opacity(0.2), lineWidth: 1)
            )
            .padding(.all, 12) // Equal padding all around
        }
    }
    
    private var autocompletePopupOverlay: some View {
        Group {
            if autocomplete.showDropdown {
                VStack {
                    // Position popup in the upper portion of the window
                    Spacer()
                        .frame(height: 60) // Give some space from top
                    
                    HStack {
                        Spacer() // Push to right
                        
                        AutocompletePopup(
                            suggestions: autocomplete.allSuggestions,
                            selectedIndex: autocomplete.selectedIndex,
                            visibleStartIndex: autocomplete.visibleStartIndex,
                            currentInput: currentCommand,
                            onItemClick: { index in
                                autocomplete.selectIndex(index)
                                currentCommand = autocomplete.acceptSelectedSuggestion()
                            }
                        )
                        .environmentObject(themeManager)
                        
                        Spacer()
                            .frame(width: 20) // Small margin from right edge
                    }
                    
                    Spacer() // Push everything up but leave space for control bar
                        .frame(height: 120) // Leave space for control bar at bottom
                }
                .animation(.easeOut(duration: 0.2), value: autocomplete.showDropdown)
            }
        }
    }
    
    private var directoryBrowserOverlay: some View {
        Group {
            if showDirectoryBrowser {
                VStack {
                    // Position directory browser in the upper portion
                    Spacer()
                        .frame(height: 60) // Give some space from top
                    
                    HStack(alignment: .top, spacing: 0) {
                        CompactPopup(
                            items: directoryItems,
                            selectedIndex: selectedDirectoryIndex,
                            onItemSelect: { index in
                                selectedDirectoryIndex = index
                            },
                            onDismiss: {
                                closeDirectoryBrowser()
                            }
                        )
                        .environmentObject(themeManager)
                        .focused($isDirectoryPopupFocused)
                        
                        Spacer() // Push popup to left
                    }
                    .padding(.leading, 20) // Small margin from left edge
                    
                    Spacer() // Push everything up but leave space for control bar
                        .frame(height: 120) // Leave space for control bar at bottom
                }
                .onTapGesture {
                    closeDirectoryBrowser()
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: showDirectoryBrowser)
    }
    
    // MARK: - Focus Management Methods
    
    private func updateFocusStates() {
        switch currentFocus {
        case .input:
            isInputFocused = true
            isDirectoryPopupFocused = false
        case .directoryPopup:
            isInputFocused = false
            isDirectoryPopupFocused = true
        case .none:
            isInputFocused = false
            isDirectoryPopupFocused = false
        }
    }
    
    private func setFocus(to target: FocusTarget) {
        currentFocus = target
    }
    
    private func openDirectoryBrowser() {
        loadDirectoryItems()
        showDirectoryBrowser = true
        setFocus(to: .directoryPopup)
    }
    
    private func closeDirectoryBrowser() {
        showDirectoryBrowser = false
        setFocus(to: .input)
    }
    
    private func handleAutocompleteVisibilityChange() {
        // If autocomplete popup appears while directory browser is open, close directory browser
        if autocomplete.showDropdown && showDirectoryBrowser {
            closeDirectoryBrowser()
        }
        // If autocomplete popup disappears and no other popup is open, ensure input has focus
        else if !autocomplete.showDropdown && !showDirectoryBrowser && currentFocus != .input {
            setFocus(to: .input)
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateFileContext() {
        fileContext = FileContext(currentDirectory: terminal.currentDirectory)
    }
    
    private func loadDirectoryItems() {
        var items: [PopupItem] = []
        
        // Add "Browse Files" option
        items.append(PopupItem(
            id: "browse",
            text: "Browse Files",
            icon: "doc.text.magnifyingglass",
            type: .file,
            action: {
                showFileBrowser = true
                closeDirectoryBrowser()
            }
        ))
        
        // Add parent directory if not at root
        let currentURL = URL(fileURLWithPath: terminal.currentDirectory)
        if currentURL.path != "/" {
            let parentPath = currentURL.deletingLastPathComponent().path
            items.append(PopupItem(
                id: "parent",
                text: ".. (Parent Directory)",
                icon: "arrow.up.left",
                type: .parent,
                action: {
                    navigateToDirectory(parentPath)
                }
            ))
        }
        
        // Add current directory contents
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: terminal.currentDirectory)
            let sortedContents = contents.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            
            for item in sortedContents {
                let fullPath = (terminal.currentDirectory as NSString).appendingPathComponent(item)
                var isDirectory: ObjCBool = false
                
                if FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDirectory) {
                    let itemType: PopupItem.PopupItemType = isDirectory.boolValue ? .directory : .file
                    let icon = isDirectory.boolValue ? "folder.fill" : getFileIcon(for: item)
                    
                    items.append(PopupItem(
                        id: item,
                        text: item,
                        icon: icon,
                        type: itemType,
                        action: {
                            if isDirectory.boolValue {
                                navigateToDirectory(fullPath)
                            }
                        }
                    ))
                }
            }
        } catch {
            print("Error loading directory contents: \(error)")
        }
        
        directoryItems = items
        selectedDirectoryIndex = 0
    }
    
    private func getFileIcon(for filename: String) -> String {
        let pathExtension = URL(fileURLWithPath: filename).pathExtension.lowercased()
        switch pathExtension {
        case "pdf":
            return "doc.fill"
        case "txt", "md":
            return "doc.text.fill"
        case "jpg", "jpeg", "png", "gif":
            return "photo.fill"
        case "mp4", "mov", "avi":
            return "video.fill"
        case "mp3", "wav", "m4a":
            return "music.note"
        case "zip", "tar", "gz":
            return "archivebox.fill"
        case "json", "xml":
            return "doc.badge.gearshape.fill"
        case "csv":
            return "tablecells.fill"
        default:
            return "doc.fill"
        }
    }
    
    private func formatDirectoryPath(_ path: String) -> String {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
        var displayPath = path
        
        // Replace home directory with ~
        if path.hasPrefix(homeDirectory) {
            displayPath = path.replacingOccurrences(of: homeDirectory, with: "~")
        }
        
        // Split path components
        let components = displayPath.components(separatedBy: "/").filter { !$0.isEmpty }
        
        // If it's just ~, return it
        if components.isEmpty || (components.count == 1 && components[0] == "~") {
            return "~"
        }
        
        // If deeper than 3 levels, show only last 3
        if components.count > 3 {
            let lastThree = Array(components.suffix(3))
            return ".../" + lastThree.joined(separator: "/")
        }
        
        // Otherwise show full path
        return components.joined(separator: "/")
    }
    
    private func handleGeometryChange(_ textFrame: CGRect, _ promptW: CGFloat) {
        textFieldFrame = textFrame
        promptWidth = promptW
    }
    
    private func navigateToDirectory(_ path: String) {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue {
            FileManager.default.changeCurrentDirectoryPath(path)
            terminal.currentDirectory = path
            terminal.setupPrompt()
            updateFileContext()
            closeDirectoryBrowser()
        }
    }
}

#Preview {
    @Previewable @StateObject var themeManager = ThemeManager()
    @Previewable @StateObject var terminal = TerminalSession()
    @Previewable @StateObject var autocomplete = AutocompleteEngine()
    @Previewable @State var command = ""
    @Previewable @FocusState var focused: Bool
    
    return ControlBarSimplified(
        currentCommand: $command,
        isInputFocused: $focused,
        autocomplete: autocomplete,
        terminal: terminal,
        onExecuteCommand: { },
        onHistoryNavigation: { _ in }
    )
    .environmentObject(themeManager)
    .padding()
}
