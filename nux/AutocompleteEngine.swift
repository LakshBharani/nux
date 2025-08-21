import Foundation
import SwiftUI

class AutocompleteEngine: ObservableObject {
    @Published var ghostText: String = ""
    @Published var currentSuggestion: String = ""
    @Published var allSuggestions: [String] = []
    @Published var showDropdown: Bool = false
    @Published var selectedIndex: Int = 0
    @Published var visibleStartIndex: Int = 0
    
    private let maxVisibleItems = AutocompleteConstants.maxVisibleItems
    
    private let commonCommands = [
        "ls", "cd", "pwd", "mkdir", "rmdir", "rm", "cp", "mv", "cat", "grep",
        "find", "which", "chmod", "chown", "ps", "top", "kill", "killall",
        "git status", "git add", "git commit", "git push", "git pull", "git clone",
        "git checkout", "git branch", "git merge", "git log", "git diff",
        "npm install", "npm start", "npm run", "npm test", "npm build",
        "yarn install", "yarn start", "yarn add", "yarn remove",
        "python", "python3", "node", "swift", "swiftc", "xcodebuild",
        "brew install", "brew update", "brew upgrade", "brew search",
        "docker run", "docker build", "docker ps", "docker stop",
        "ssh", "scp", "rsync", "curl", "wget", "ping", "traceroute",
        "tar", "zip", "unzip", "gzip", "gunzip", "head", "tail", "less", "more"
    ]
    
    private var fileCache: [String] = []
    private var directoryCache: [String] = []
    private var commandHistory: [String] = []
    
    func updateInput(_ input: String, currentDirectory: String) {
        guard !input.isEmpty else {
            clearSuggestions()
            return
        }
        
        // Update file and directory cache
        updateFileCache(currentDirectory: currentDirectory)
        
        // Get suggestions based on input
        let suggestions = getSuggestions(for: input, currentDirectory: currentDirectory)
        allSuggestions = suggestions
        
        // Set the best match as ghost text
        if let bestMatch = suggestions.first {
            let completionWord = getCompletionWord(from: bestMatch, input: input)
            if bestMatch.hasPrefix(input) && bestMatch.count > input.count {
                ghostText = String(bestMatch.dropFirst(input.count))
                currentSuggestion = bestMatch
            } else {
                ghostText = ""
                currentSuggestion = bestMatch
            }
        } else {
            clearSuggestions()
        }
    }
    
    func getCompletionWord(from suggestion: String, input: String) -> String {
        let inputComponents = input.components(separatedBy: .whitespaces)
        let suggestionComponents = suggestion.components(separatedBy: .whitespaces)
        
        // If we're completing a command (single word input)
        if inputComponents.count == 1 {
            return suggestionComponents.first ?? suggestion
        }
        
        // If we're completing an argument, return just the last part being completed
        if let lastInputWord = inputComponents.last,
           let matchingComponent = suggestionComponents.first(where: { $0.hasPrefix(lastInputWord) }) {
            return matchingComponent
        }
        
        // Fallback: return the last component of the suggestion
        return suggestionComponents.last ?? suggestion
    }
    
    func showDropdownSuggestions() {
        if !allSuggestions.isEmpty {
            showDropdown = true
            selectedIndex = 0
            visibleStartIndex = 0
            if allSuggestions.count > selectedIndex {
                currentSuggestion = allSuggestions[selectedIndex]
            }
        }
    }
    
    func navigateDropdown() {
        guard showDropdown && !allSuggestions.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % allSuggestions.count
        currentSuggestion = allSuggestions[selectedIndex]
        
        // Auto-scroll to keep selected item visible
        updateVisibleRange()
    }
    
    func navigateUp() {
        guard showDropdown && !allSuggestions.isEmpty else { return }
        selectedIndex = selectedIndex > 0 ? selectedIndex - 1 : allSuggestions.count - 1
        currentSuggestion = allSuggestions[selectedIndex]
        updateVisibleRange()
    }
    
    func navigateDown() {
        guard showDropdown && !allSuggestions.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % allSuggestions.count
        currentSuggestion = allSuggestions[selectedIndex]
        updateVisibleRange()
    }
    
    func selectIndex(_ index: Int) {
        guard showDropdown && index >= 0 && index < allSuggestions.count else { return }
        selectedIndex = index
        currentSuggestion = allSuggestions[selectedIndex]
        updateVisibleRange()
    }
    
    private func updateVisibleRange() {
        // If selected item is below visible range, scroll down
        if selectedIndex >= visibleStartIndex + maxVisibleItems {
            visibleStartIndex = selectedIndex - maxVisibleItems + 1
        }
        // If selected item is above visible range, scroll up
        else if selectedIndex < visibleStartIndex {
            visibleStartIndex = selectedIndex
        }
        
        // Ensure we don't scroll past the end
        let maxStartIndex = max(0, allSuggestions.count - maxVisibleItems)
        visibleStartIndex = min(visibleStartIndex, maxStartIndex)
    }
    
    func acceptSelectedSuggestion() -> String {
        let result = showDropdown ? currentSuggestion : currentSuggestion
        hideDropdown()
        return result
    }
    
    func hideDropdown() {
        showDropdown = false
        selectedIndex = 0
        visibleStartIndex = 0
        ghostText = ""
    }
    
    func clearSuggestions() {
        ghostText = ""
        currentSuggestion = ""
        allSuggestions = []
        showDropdown = false
        selectedIndex = 0
        visibleStartIndex = 0
    }
    
    func addToHistory(_ command: String) {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && (commandHistory.isEmpty || commandHistory.last != trimmed) {
            commandHistory.append(trimmed)
            // Keep only last N commands
            if commandHistory.count > TerminalConstants.maxHistoryItems {
                commandHistory.removeFirst()
            }
        }
    }
    
    private func updateFileCache(currentDirectory: String) {
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: currentDirectory)
            fileCache.removeAll()
            directoryCache.removeAll()
            
            for item in contents {
                let fullPath = (currentDirectory as NSString).appendingPathComponent(item)
                var isDirectory: ObjCBool = false
                
                if FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDirectory) {
                    if isDirectory.boolValue {
                        directoryCache.append(item)
                    } else {
                        fileCache.append(item)
                    }
                }
            }
        } catch {
            // Ignore errors
        }
    }
    
    private func getSuggestions(for input: String, currentDirectory: String) -> [String] {
        let components = input.components(separatedBy: .whitespaces)
        guard let firstComponent = components.first else { return [] }
        
        var suggestions: [String] = []
        
        if components.count == 1 {
            // Suggesting commands
            suggestions.append(contentsOf: commonCommands.filter { $0.hasPrefix(firstComponent) })
            suggestions.append(contentsOf: commandHistory.filter { $0.hasPrefix(firstComponent) })
        } else {
            // Suggesting file/directory names for command arguments
            let lastComponent = components.last ?? ""
            
            // Add directory suggestions
            let dirSuggestions = directoryCache
                .filter { $0.hasPrefix(lastComponent) }
                .map { components.dropLast().joined(separator: " ") + " " + $0 + "/" }
            suggestions.append(contentsOf: dirSuggestions)
            
            // Add file suggestions
            let fileSuggestions = fileCache
                .filter { $0.hasPrefix(lastComponent) }
                .map { components.dropLast().joined(separator: " ") + " " + $0 }
            suggestions.append(contentsOf: fileSuggestions)
            
            // Special handling for cd command - only directories
            if firstComponent == "cd" {
                suggestions = dirSuggestions
            }
        }
        
        // Remove duplicates and sort
        return Array(Set(suggestions)).sorted()
    }
}

// File context information
struct FileContext {
    let currentDirectory: String
    let fileCount: Int
    let directoryCount: Int
    let totalSize: String?
    
    init(currentDirectory: String) {
        self.currentDirectory = currentDirectory
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: currentDirectory)
            var fileCount = 0
            var directoryCount = 0
            var totalSize: Int64 = 0
            
            for item in contents {
                let fullPath = (currentDirectory as NSString).appendingPathComponent(item)
                var isDirectory: ObjCBool = false
                
                if FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDirectory) {
                    if isDirectory.boolValue {
                        directoryCount += 1
                    } else {
                        fileCount += 1
                        if let attributes = try? FileManager.default.attributesOfItem(atPath: fullPath),
                           let size = attributes[.size] as? Int64 {
                            totalSize += size
                        }
                    }
                }
            }
            
            self.fileCount = fileCount
            self.directoryCount = directoryCount
            self.totalSize = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
        } catch {
            self.fileCount = 0
            self.directoryCount = 0
            self.totalSize = nil
        }
    }
    
    var summary: String {
        let dirText = directoryCount == 1 ? "dir" : "dirs"
        let fileText = fileCount == 1 ? "file" : "files"
        return "\(directoryCount) \(dirText), \(fileCount) \(fileText)"
    }
}
