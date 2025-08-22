import Foundation
import SwiftUI
import AppKit

enum TerminalOutputType {
    case command
    case output
    case error
    case success
    case aiResponse  // New type for Agent Assist responses
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

    // Provide a snapshot of the shell environment for AI context building
    func environmentSnapshot() -> [String: String] {
        if let env = cachedEnvironment { return env }
        return ProcessInfo.processInfo.environment
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
        print("🖥️ [DEBUG] TerminalSession.executeCommand() called with: '\(command)'")
        let startTime = Date()
        let commandDirectory = currentDirectory
        
        // Add command to output
        outputs.append(TerminalOutput(text: command, type: .command, prompt: prompt))
        let commandIndex = outputs.count - 1
        print("🖥️ [DEBUG] Added command to outputs, index: \(commandIndex)")
        
        // Handle built-in commands
        if handleBuiltInCommand(command) {
            updateCommandMetadata(at: commandIndex, directory: commandDirectory, executionTime: Date().timeIntervalSince(startTime))
            return
        }
        
        // Execute shell command
        executeShellCommand(command, directory: commandDirectory, startTime: startTime, commandIndex: commandIndex)
    }
    
    // Execute command silently for AI - doesn't add to visible outputs but returns result
    func executeCommandSilently(_ command: String) async -> (output: String, error: String?) {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                
                process.standardOutput = outputPipe
                process.standardError = errorPipe
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                
                // Use cached environment or fallback to basic environment
                if let cachedEnv = self.cachedEnvironment {
                    process.environment = cachedEnv
                } else {
                    var env = ProcessInfo.processInfo.environment
                    env["PATH"] = "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/go/bin:/opt/homebrew/bin:/opt/homebrew/sbin"
                    process.environment = env
                }
                
                // Execute command in current directory
                let shellCommand = """
                cd '\(self.currentDirectory)' && \(command)
                """
                process.arguments = ["-c", shellCommand]
                
                do {
                    try process.run()
                    
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    
                    process.waitUntilExit()
                    
                    let output = String(data: outputData, encoding: .utf8) ?? ""
                    let error = String(data: errorData, encoding: .utf8)
                    let errorText = (error?.isEmpty == false) ? error : nil
                    
                    continuation.resume(returning: (output.trimmingCharacters(in: .whitespacesAndNewlines), errorText?.trimmingCharacters(in: .whitespacesAndNewlines)))
                } catch {
                    continuation.resume(returning: ("", "Failed to execute command: \(error.localizedDescription)"))
                }
            }
        }
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
        
        let targetPath = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
        let fullPath: String
        
        if targetPath.hasPrefix("/") {
            // Absolute path
            fullPath = targetPath
        } else if targetPath == ".." {
            // Parent directory
            fullPath = URL(fileURLWithPath: currentDirectory).deletingLastPathComponent().path
        } else if targetPath == "~" {
            // Home directory
            fullPath = FileManager.default.homeDirectoryForCurrentUser.path
        } else if targetPath.hasPrefix("~") {
            // Home-relative path (e.g., ~/Documents)
            fullPath = NSString(string: targetPath).expandingTildeInPath
        } else {
            // Relative path - build the full path and let the system validate it
            fullPath = URL(fileURLWithPath: currentDirectory).appendingPathComponent(targetPath).path
        }
        
        changeToDirectory(fullPath)
    }
    
    private func changeToDirectory(_ path: String) {
        // Validate the directory exists before changing
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue {
            currentDirectory = path
            setupPrompt()
        } else {
            outputs.append(TerminalOutput(text: "cd: no such file or directory: \(path)", type: .error))
        }
    }
    
    // Update directory silently for AI commands without adding to outputs
    func updateDirectorySilently(_ path: String) {
        let expandedPath: String
        if path.hasPrefix("~") {
            expandedPath = NSString(string: path).expandingTildeInPath
        } else if path.hasPrefix("/") {
            expandedPath = path
        } else {
            expandedPath = URL(fileURLWithPath: currentDirectory).appendingPathComponent(path).path
        }
        
        // Validate the directory exists before changing
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory) && isDirectory.boolValue {
            currentDirectory = expandedPath
            setupPrompt()
            print("🖥️ [DEBUG] AI updated terminal directory to: \(currentDirectory)")
        } else {
            print("🖥️ [DEBUG] AI attempted to change to non-existent directory: \(expandedPath)")
        }
    }
    
    // Add AI response as terminal output entry
    func addAIResponse(_ response: AIConversationEntry) {
        let aiOutput = TerminalOutput(
            text: response.id.uuidString, // Store the conversation ID to reference the full response
            type: .aiResponse,
            prompt: "",
            executionTime: nil,
            directory: currentDirectory
        )
        outputs.append(aiOutput)
        print("🖥️ [DEBUG] Added AI response to terminal outputs at index \(outputs.count - 1)")
    }
    
    // Execute command for AI through main terminal session but capture output without visible display
    func executeCommandForAI(_ command: String) async -> (output: String, error: String?) {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                print("🖥️ [DEBUG] AI executing command through main terminal: '\(command)'")
                let startTime = Date()
                let commandDirectory = self.currentDirectory
                let originalOutputCount = self.outputs.count
                
                // Handle built-in commands first
                if self.handleBuiltInCommand(command) {
                    // For built-in commands, capture any new outputs
                    let newOutputs = Array(self.outputs.dropFirst(originalOutputCount))
                    let output = newOutputs.compactMap { output in
                        switch output.type {
                        case .output, .success:
                            return output.text
                        default:
                            return nil
                        }
                    }.joined(separator: "\n")
                    
                    let error = newOutputs.first { $0.type == .error }?.text
                    
                    // Remove the AI command outputs from visible terminal to keep it clean
                    if self.outputs.count > originalOutputCount {
                        self.outputs.removeSubrange(originalOutputCount...)
                    }
                    
                    continuation.resume(returning: (output, error))
                    return
                }
                
                // For shell commands, execute through the main shell process
                self.executeShellCommandForAI(command, directory: commandDirectory, startTime: startTime, originalOutputCount: originalOutputCount, continuation: continuation)
            }
        }
    }
    
    private func executeShellCommandForAI(_ command: String, directory: String, startTime: Date, originalOutputCount: Int, continuation: CheckedContinuation<(output: String, error: String?), Never>) {
        // Use the same shell process approach as the main terminal for consistency
        // This ensures environment variables, aliases, and other state are preserved
        executeShellCommandWithCapture(command, directory: directory, startTime: startTime, commandIndex: -1) { [weak self] capturedOutput, capturedError in
            DispatchQueue.main.async {
                continuation.resume(returning: (capturedOutput ?? "", capturedError))
            }
        }
    }
    
    private func executeShellCommandWithCapture(_ command: String, directory: String, startTime: Date, commandIndex: Int, completion: @escaping (String?, String?) -> Void) {
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
        
        // Execute in current directory and capture new directory state
        let shellCommand = """
        cd '\(currentDirectory)' && \(command) && pwd
        """
        process.arguments = ["-c", shellCommand]
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try process.run()
                
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                
                process.waitUntilExit()
                
                let output = String(data: outputData, encoding: .utf8) ?? ""
                let errorOutput = String(data: errorData, encoding: .utf8)
                
                // Extract directory info from output
                let outputLines = output.components(separatedBy: .newlines)
                let newDirectory = outputLines.last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let commandOutput = outputLines.dropLast().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                
                DispatchQueue.main.async {
                    // Update directory if it changed and this is for AI (commandIndex == -1)
                    if commandIndex == -1 && !newDirectory.isEmpty && newDirectory != self.currentDirectory {
                        self.currentDirectory = newDirectory
                        self.setupPrompt()
                        print("🖥️ [DEBUG] AI command updated directory to: \(self.currentDirectory)")
                    }
                    
                    let finalError = (errorOutput?.isEmpty == false) ? errorOutput : nil
                    completion(commandOutput, finalError)
                }
            } catch {
                DispatchQueue.main.async {
                    completion("", "Failed to execute command: \(error.localizedDescription)")
                }
            }
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
                        print("🖥️ [DEBUG] Adding error output: '\(trimmedError)'")
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
