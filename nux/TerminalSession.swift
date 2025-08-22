import Foundation
import SwiftUI

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
        
        let targetPath = components[1]
        var fullPath: String
        
        if targetPath.hasPrefix("/") {
            fullPath = targetPath
        } else if targetPath == ".." {
            fullPath = URL(fileURLWithPath: currentDirectory).deletingLastPathComponent().path
        } else if targetPath == "~" {
            fullPath = FileManager.default.homeDirectoryForCurrentUser.path
        } else {
            fullPath = URL(fileURLWithPath: currentDirectory).appendingPathComponent(targetPath).path
        }
        
        changeToDirectory(fullPath)
    }
    
    private func changeToDirectory(_ path: String) {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue {
            currentDirectory = path
            setupPrompt()
        } else {
            outputs.append(TerminalOutput(text: "cd: no such file or directory: \(path)", type: .error))
        }
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
}
