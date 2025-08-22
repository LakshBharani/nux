import Foundation
import SwiftUI
import AppKit

enum TerminalOutputType {
    case command
    case output
    case error
    case success
}

struct TerminalOutput {
    let text: String
    let type: TerminalOutputType
    let prompt: String
    let timestamp: Date
    let executionTime: TimeInterval?
    let directory: String?
    
    init(text: String, type: TerminalOutputType, prompt: String = "", executionTime: TimeInterval? = nil, directory: String? = nil) {
        self.text = text
        self.type = type
        self.prompt = prompt
        self.timestamp = Date()
        self.executionTime = executionTime
        self.directory = directory
    }
}

@MainActor
class TerminalSession: ObservableObject {
    @Published var outputs: [TerminalOutput] = []
    @Published var currentDirectory: String = ""
    @Published var prompt: String = ""
    @Published var showFileViewer = false
    @Published var showVimEditor = false
    @Published var showVimShell = false
    @Published var isInVimMode = false
    @Published var fileToView: String = ""
    @Published var fileToEdit: String = ""
    
    private var process: Process?
    private var inputPipe = Pipe()
    private var outputPipe = Pipe()
    private var errorPipe = Pipe()
    private var cachedEnvironment: [String: String]?
    private var environmentLoaded = false
    
    init(startDirectory: String = "/") {
        self.currentDirectory = startDirectory
        setupPrompt()
    }
    
    func startSession() {
        // Start with a ready prompt; UI handles empty state
        setupPrompt()
        loadShellEnvironment()
    }
    
    private func loadShellEnvironment() {
        guard !environmentLoaded else { return }
        
        let process = Process()
        let outputPipe = Pipe()
        
        process.standardOutput = outputPipe
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        
        // Load shell environment and export it
        let shellCommand = """
        source ~/.zshrc 2>/dev/null || true
        source ~/.zprofile 2>/dev/null || true
        env
        """
        process.arguments = ["-c", shellCommand]
        
        do {
            try process.run()
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            
            if let output = String(data: data, encoding: .utf8) {
                var env: [String: String] = [:]
                
                // Parse environment variables
                let lines = output.components(separatedBy: .newlines)
                for line in lines {
                    if let range = line.range(of: "=") {
                        let key = String(line[..<range.lowerBound])
                        let value = String(line[range.upperBound...])
                        env[key] = value
                    }
                }
                
                // Ensure PATH includes common directories
                let commonPaths = "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/go/bin:/opt/homebrew/bin:/opt/homebrew/sbin"
                if let existingPath = env["PATH"] {
                    env["PATH"] = "\(existingPath):\(commonPaths)"
                } else {
                    env["PATH"] = commonPaths
                }
                
                cachedEnvironment = env
                environmentLoaded = true
            }
        } catch {
            // Fallback to basic environment
            var env = ProcessInfo.processInfo.environment
            env["PATH"] = "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/go/bin:/opt/homebrew/bin:/opt/homebrew/sbin"
            cachedEnvironment = env
            environmentLoaded = true
        }
    }
    
    private func addWelcomeMessage() {
        let welcomeText = """
        Welcome to nux Terminal
        Type 'help' for available commands
        """
        outputs.append(TerminalOutput(text: welcomeText, type: .success))
    }
    
    func setupPrompt() {
        prompt = "$"
    }
    
    func executeCommand(_ command: String) {
        let startTime = Date()
        let commandDirectory = currentDirectory
        
        // Add command to output
        outputs.append(TerminalOutput(text: command, type: .command, prompt: prompt))
        let commandIndex = outputs.count - 1
        
        // Handle built-in commands
        if handleBuiltInCommand(command) {
            updateCommandMetadata(at: commandIndex, directory: commandDirectory, executionTime: Date().timeIntervalSince(startTime))
            return
        }
        
        // Execute shell command
        executeShellCommand(command, directory: commandDirectory, startTime: startTime, commandIndex: commandIndex)
    }
    
    private func handleBuiltInCommand(_ command: String) -> Bool {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = trimmedCommand.components(separatedBy: .whitespacesAndNewlines)
        guard let firstComponent = components.first else { return false }
        
        switch firstComponent.lowercased() {
        case "help":
            showHelp()
            return true
        case "clear":
            clearTerminal()
            return true
        case "cd":
            changeDirectory(components)
            return true
        case "open", "view", "cat":
            openFile(components)
            return true
        case "edit", "vim", "nano":
            editFile(components)
            return true
        case "vimshell":
            openVimShell()
            return true
        default:
            return false
        }
    }
    
    private func showHelp() {
        let helpText = """
        Built-in commands:
          help     - Show this help message
          clear    - Clear the terminal
          cd       - Change directory
          open     - Open file in viewer (open <filename>)
          view     - View file content (view <filename>)
          cat      - Display file content (cat <filename>)
          edit     - Edit file with vim (edit <filename>)
          vim      - Edit file with vim (vim <filename>)
          nano     - Edit file with nano (nano <filename>)
          vimshell - Enter full vim shell mode
          
        All other commands are executed in the shell.
        """
        outputs.append(TerminalOutput(text: helpText, type: .output))
    }
    
    private func clearTerminal() {
        outputs.removeAll()
    }
    
    private func changeDirectory(_ components: [String]) {
        guard components.count > 1 else {
            // Go to home directory
            let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
            changeToDirectory(homeDir)
            return
        }
        
        let targetPath = components[1].trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var fullPath: String
        
        if targetPath.hasPrefix("/") {
            fullPath = targetPath
        } else if targetPath == ".." {
            fullPath = URL(fileURLWithPath: currentDirectory).deletingLastPathComponent().path
        } else if targetPath == "~" {
            fullPath = FileManager.default.homeDirectoryForCurrentUser.path
        } else {
            // For relative paths, check case-sensitive directory existence
            do {
                let contents = try FileManager.default.contentsOfDirectory(atPath: currentDirectory)
                let matchingItem = contents.first { $0.lowercased() == targetPath.lowercased() }
                
                if let match = matchingItem {
                    if match == targetPath {
                        // Exact case match found
                        fullPath = URL(fileURLWithPath: currentDirectory).appendingPathComponent(targetPath).path
                    } else {
                        // Case-insensitive match but different case
                        outputs.append(TerminalOutput(text: "cd: no such file or directory: \(components[1])", type: .error))
                        return
                    }
                } else {
                    // No match at all
                    outputs.append(TerminalOutput(text: "cd: no such file or directory: \(components[1])", type: .error))
                    return
                }
            } catch {
                outputs.append(TerminalOutput(text: "cd: no such file or directory: \(components[1])", type: .error))
                return
            }
        }
        
        changeToDirectory(fullPath)
    }
    
    private func changeToDirectory(_ path: String) {
        currentDirectory = path
        setupPrompt()
    }
    
    private func executeShellCommand(_ command: String, directory: String, startTime: Date, commandIndex: Int) {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        
        // Use cached environment or fallback to basic environment
        if let cachedEnv = cachedEnvironment {
            process.environment = cachedEnv
        } else {
            var env = ProcessInfo.processInfo.environment
            env["PATH"] = "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/go/bin:/opt/homebrew/bin:/opt/homebrew/sbin"
            process.environment = env
        }
        
        // Simple command execution without loading shell config every time
        let shellCommand = """
        cd '\(currentDirectory)' && \(command) && pwd
        """
        process.arguments = ["-c", shellCommand]
        
        do {
            try process.run()
            
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            
            process.waitUntilExit()
            
            // Split the output to separate command output from the pwd result
            if !outputData.isEmpty {
                if let raw = String(data: outputData, encoding: .utf8) {
                    // Trim trailing newlines so the last non-empty line is truly the pwd
                    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        let lines = trimmed.components(separatedBy: .newlines)
                        if let last = lines.last {
                            let newDirectory = last.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !newDirectory.isEmpty && newDirectory != currentDirectory {
                                currentDirectory = newDirectory
                                setupPrompt()
                            }
                        }
                        // All lines except the last are the command output
                        let commandOutput = lines.dropLast().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                        if !commandOutput.isEmpty {
                            outputs.append(TerminalOutput(text: commandOutput, type: .output))
                        }
                    }
                }
            }
            
            if !errorData.isEmpty {
                if let error = String(data: errorData, encoding: .utf8) {
                    let trimmedError = error.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedError.isEmpty {
                        outputs.append(TerminalOutput(text: trimmedError, type: .error))
                    }
                }
            }
            
        } catch {
            outputs.append(TerminalOutput(text: "Error executing command: \(error.localizedDescription)", type: .error))
        }
        
        // Update command metadata with execution time using original command index
        updateCommandMetadata(at: commandIndex, directory: directory, executionTime: Date().timeIntervalSince(startTime))
    }
    
    private func updateCommandMetadata(at index: Int, directory: String, executionTime: TimeInterval) {
        guard index >= 0 && index < outputs.count else { return }
        
        let originalOutput = outputs[index]
        let updatedOutput = TerminalOutput(
            text: originalOutput.text,
            type: originalOutput.type,
            prompt: originalOutput.prompt,
            executionTime: executionTime,
            directory: directory
        )
        outputs[index] = updatedOutput
    }
    
    // MARK: - File Operations
    
    private func openFile(_ components: [String]) {
        guard components.count > 1 else {
            outputs.append(TerminalOutput(text: "Usage: open <filename>", type: .error))
            return
        }
        
        // Join all components after the command to handle filenames with spaces
        let fileName = Array(components.dropFirst()).joined(separator: " ")
        let fullPath = resolvePath(fileName)
        
        if FileManager.default.fileExists(atPath: fullPath) {
            // Check if it's a text file that we can handle internally
            let fileType = FileViewer.FileType.determine(for: fullPath)
            
            if fileType == .text {
                // Use internal viewer for text files
                fileToView = fullPath
                showFileViewer = true
            } else {
                // Use system default app for non-text files
                let url = URL(fileURLWithPath: fullPath)
                if NSWorkspace.shared.open(url) {
                    outputs.append(TerminalOutput(text: "Opened \(fileName) with system default app", type: .success))
                } else {
                    outputs.append(TerminalOutput(text: "Error opening \(fileName) with system app", type: .error))
                }
            }
        } else {
            outputs.append(TerminalOutput(text: "File not found: \(fileName)", type: .error))
        }
    }
    
    private func editFile(_ components: [String]) {
        guard components.count > 1 else {
            outputs.append(TerminalOutput(text: "Usage: edit <filename>", type: .error))
            return
        }
        
        // Join all components after the command to handle filenames with spaces
        let fileName = Array(components.dropFirst()).joined(separator: " ")
        let fullPath = resolvePath(fileName)
        
        if FileManager.default.fileExists(atPath: fullPath) {
            // Enter vim mode with the file
            fileToEdit = fullPath
            isInVimMode = true
            outputs.append(TerminalOutput(text: "Entering vim mode for \(fileName)", type: .success))
        } else {
            outputs.append(TerminalOutput(text: "File not found: \(fileName)", type: .error))
        }
    }
    
    private func resolvePath(_ fileName: String) -> String {
        if fileName.hasPrefix("/") {
            return fileName
        } else if fileName.hasPrefix("~") {
            return fileName.replacingOccurrences(of: "~", with: FileManager.default.homeDirectoryForCurrentUser.path)
        } else {
            return URL(fileURLWithPath: currentDirectory).appendingPathComponent(fileName).path
        }
    }
    
    private func openVimShell() {
        isInVimMode = true
        outputs.append(TerminalOutput(text: "Entering Vim Shell mode", type: .success))
    }
}
