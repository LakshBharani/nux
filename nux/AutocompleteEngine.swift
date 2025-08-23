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
        "open", "view", "edit", "vim", "nano",
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
        
        updateFileCache(currentDirectory: currentDirectory)
        
        let suggestions = getSuggestions(for: input, currentDirectory: currentDirectory)
        allSuggestions = suggestions
        
        if let bestMatch = suggestions.first {
            let ghostTextWord = getGhostTextWord(from: bestMatch, input: input)
            ghostText = ghostTextWord
            currentSuggestion = bestMatch
        } else {
            clearSuggestions()
        }
    }
    
    func getCompletionWord(from suggestion: String, input: String) -> String {
        let inputComponents = input.components(separatedBy: .whitespaces)
        let suggestionComponents = suggestion.components(separatedBy: .whitespaces)
        
        if inputComponents.count == 1 {
            return suggestionComponents.first ?? suggestion
        }
        
        if suggestionComponents.count > 1 {
            let argumentParts = Array(suggestionComponents.dropFirst())
            let argumentString = argumentParts.joined(separator: " ")
            
            if argumentString.contains("/") {
                return URL(fileURLWithPath: argumentString).lastPathComponent
            }
            
            return argumentString
        }
        
        if suggestion.contains("/") {
            return URL(fileURLWithPath: suggestion).lastPathComponent
        }
        
        return suggestion
    }
    
    func getGhostTextWord(from suggestion: String, input: String) -> String {
        let inputComponents = input.components(separatedBy: .whitespaces)
        let suggestionComponents = suggestion.components(separatedBy: .whitespaces)
        
        if inputComponents.count == 1 {
            let command = suggestionComponents.first ?? suggestion
            let lastInputWord = inputComponents.last ?? ""
            
            if command.lowercased().hasPrefix(lastInputWord.lowercased()) && command.count > lastInputWord.count {
                return String(command.dropFirst(lastInputWord.count))
            }
            return ""
        }
        
        if suggestionComponents.count > 1 {
            let argumentParts = Array(suggestionComponents.dropFirst())
            let argumentString = argumentParts.joined(separator: " ")
            let lastInputWord = inputComponents.last ?? ""
            
            if argumentString.contains("/") {
                let filename = URL(fileURLWithPath: argumentString).lastPathComponent
                
                if filename.lowercased().hasPrefix(lastInputWord.lowercased()) && filename.count > lastInputWord.count {
                    return String(filename.dropFirst(lastInputWord.count))
                }
                return ""
            }
            
            if argumentString.lowercased().hasPrefix(lastInputWord.lowercased()) && argumentString.count > lastInputWord.count {
                return String(argumentString.dropFirst(lastInputWord.count))
            }
            return ""
        }
        
        if suggestion.contains("/") {
            let filename = URL(fileURLWithPath: suggestion).lastPathComponent
            let lastInputWord = inputComponents.last ?? ""
            
            if filename.lowercased().hasPrefix(lastInputWord.lowercased()) && filename.count > lastInputWord.count {
                return String(filename.dropFirst(lastInputWord.count))
            }
            return ""
        }
        
        let lastInputWord = inputComponents.last ?? ""
        if suggestion.lowercased().hasPrefix(lastInputWord.lowercased()) && suggestion.count > lastInputWord.count {
            return String(suggestion.dropFirst(lastInputWord.count))
        }
        return ""
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
        if selectedIndex >= visibleStartIndex + maxVisibleItems {
            visibleStartIndex = selectedIndex - maxVisibleItems + 1
        }
        else if selectedIndex < visibleStartIndex {
            visibleStartIndex = selectedIndex
        }
        
        let maxStartIndex = max(0, allSuggestions.count - maxVisibleItems)
        visibleStartIndex = min(visibleStartIndex, maxStartIndex)
    }
    
    func acceptSelectedSuggestion(currentInput: String) -> String {
        guard !currentSuggestion.isEmpty else {
            hideDropdown()
            return currentInput
        }
        
        let inputComponents = currentInput.components(separatedBy: .whitespaces)
        let suggestionComponents = currentSuggestion.components(separatedBy: .whitespaces)
        
        var result: String
        
        if inputComponents.count == 1 {
            result = suggestionComponents.first ?? currentSuggestion
        } else {
            let commandPart = Array(inputComponents.dropLast()).joined(separator: " ")
            let lastComponent = inputComponents.last ?? ""
            
            if suggestionComponents.count > 1 {
                let argumentParts = Array(suggestionComponents.dropFirst())
                let argumentString = argumentParts.joined(separator: " ")
                
                if argumentString.contains("/") {
                    let filename = URL(fileURLWithPath: argumentString).lastPathComponent
                    result = "\(commandPart) \(filename)"
                } else {
                    result = "\(commandPart) \(argumentString)"
                }
            } else {
                result = "\(commandPart) \(currentSuggestion)"
            }
        }
        
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
        }
    }
    
    private func getSuggestions(for input: String, currentDirectory: String) -> [String] {
        let components = input.components(separatedBy: .whitespaces)
        guard let firstComponent = components.first else { return [] }
        
        var suggestions: [String] = []
        
        if components.count == 1 {
            suggestions.append(contentsOf: commonCommands.filter { $0.lowercased().hasPrefix(firstComponent.lowercased()) })
            suggestions.append(contentsOf: commandHistory.filter { $0.lowercased().hasPrefix(firstComponent.lowercased()) })
        } else {
            let lastComponent = components.last ?? ""
            
            let dirSuggestions = directoryCache
                .filter { $0.lowercased().hasPrefix(lastComponent.lowercased()) }
                .map { $0 + "/" }
            suggestions.append(contentsOf: dirSuggestions)
            
            let fileSuggestions = fileCache
                .filter { $0.lowercased().hasPrefix(lastComponent.lowercased()) }
            suggestions.append(contentsOf: fileSuggestions)
            
            if firstComponent.lowercased() == "cd" {
                suggestions = dirSuggestions
            }
        }
        
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
