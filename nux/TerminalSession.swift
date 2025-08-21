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
    
    init(startDirectory: String = "/") {
        self.currentDirectory = startDirectory
        setupPrompt()
    }
    
    func startSession() {
        // Start with a ready prompt; UI handles empty state
        setupPrompt()
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
        
        // Add divider above command
        outputs.append(TerminalOutput(text: "─", type: .output))
        
        // Add command to output
        outputs.append(TerminalOutput(text: command, type: .command, prompt: prompt))
        
        // Handle built-in commands
        if handleBuiltInCommand(command) {
            let executionTime = Date().timeIntervalSince(startTime)
            addCommandMetadata(executionTime: executionTime, directory: commandDirectory)
            return
        }
        
        // Execute shell command
        executeShellCommand(command, startTime: startTime, directory: commandDirectory)
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
    
    private func executeShellCommand(_ command: String, startTime: Date, directory: String) {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        
        // Set up environment variables to match user's shell
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/go/bin:/opt/homebrew/bin:/opt/homebrew/sbin"
        process.environment = env
        
        // Create a command that loads user's shell configuration and executes the command
        let shellCommand = """
        source ~/.zshrc 2>/dev/null || true
        source ~/.zprofile 2>/dev/null || true
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
                if let output = String(data: outputData, encoding: .utf8) {
                    let lines = output.components(separatedBy: .newlines)
                    if lines.count > 1 {
                        // Last line should be the pwd result
                        let newDirectory = lines.last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? currentDirectory
                        if !newDirectory.isEmpty && newDirectory != currentDirectory {
                            currentDirectory = newDirectory
                            setupPrompt()
                        }
                        
                        // All lines except the last are the command output
                        let commandOutput = lines.dropLast().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                        if !commandOutput.isEmpty {
                            outputs.append(TerminalOutput(text: commandOutput, type: .output))
                        }
                    } else {
                        // Single line output (just pwd result)
                        let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmedOutput.isEmpty {
                            outputs.append(TerminalOutput(text: trimmedOutput, type: .output))
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
            
            // Add command metadata (execution time and directory)
            let executionTime = Date().timeIntervalSince(startTime)
            addCommandMetadata(executionTime: executionTime, directory: directory)
            
        } catch {
            outputs.append(TerminalOutput(text: "Error executing command: \(error.localizedDescription)", type: .error))
            let executionTime = Date().timeIntervalSince(startTime)
            addCommandMetadata(executionTime: executionTime, directory: directory)
        }
    }
    
    private func addCommandMetadata(executionTime: TimeInterval, directory: String) {
        // Find the last command output and update it with metadata
        if let lastIndex = outputs.lastIndex(where: { $0.type == .command }) {
            let originalOutput = outputs[lastIndex]
            let updatedOutput = TerminalOutput(
                text: originalOutput.text,
                type: originalOutput.type,
                prompt: originalOutput.prompt,
                executionTime: executionTime,
                directory: directory
            )
            outputs[lastIndex] = updatedOutput
        }
    }
    

}
