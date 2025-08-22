import Foundation
import SwiftUI

// MARK: - AI Context Models

struct AIAttachedCommand: Codable, Identifiable {
    let id = UUID()
    let command: String
    let output: String
    let directory: String
    let executionTime: TimeInterval
    let timestamp: Date
    let isError: Bool
    
    init(from terminalOutput: TerminalOutput, commandOutput: [TerminalOutput]) {
        self.command = terminalOutput.text
        self.directory = terminalOutput.directory ?? ""
        self.executionTime = terminalOutput.executionTime ?? 0
        self.timestamp = terminalOutput.timestamp
        
        // Collect all output after this command until the next command
        var outputText = ""
        var hasError = false
        
        for output in commandOutput {
            if output.type == .output {
                outputText += output.text + "\n"
            } else if output.type == .error {
                outputText += output.text + "\n"
                hasError = true
            }
        }
        
        self.output = outputText.trimmingCharacters(in: .whitespacesAndNewlines)
        self.isError = hasError
    }
    
    var contextString: String {
        let errorPrefix = isError ? "[ERROR] " : ""
        return """
        \(errorPrefix)Command: \(command)
        Directory: \(directory)
        Output:
        \(output)
        """
    }
}

struct AIExecutedCommand: Codable, Identifiable {
    let id = UUID()
    let command: String
    let output: String
    let error: String?
    let timestamp: Date
    let isRisky: Bool
    let wasAutoExecuted: Bool
    let directory: String
    
    init(command: String, output: String, error: String?, isRisky: Bool, wasAutoExecuted: Bool, directory: String) {
        self.command = command
        self.output = output
        self.error = error
        self.isRisky = isRisky
        self.wasAutoExecuted = wasAutoExecuted
        self.directory = directory
        self.timestamp = Date()
    }
}

struct AIConversationEntry: Codable, Identifiable {
    let id: UUID
    let prompt: String
    let response: String
    let timestamp: Date
    let attachedCommands: [AIAttachedCommand]
    let suggestedCommand: String?
    let executedCommands: [AIExecutedCommand] // Commands executed by AI during this conversation
    let pendingRiskyCommand: String? // Risky command awaiting user approval
    
    init(prompt: String, response: String, attachedCommands: [AIAttachedCommand], suggestedCommand: String?, executedCommands: [AIExecutedCommand] = [], pendingRiskyCommand: String? = nil) {
        self.id = UUID()
        self.prompt = prompt
        self.response = response
        self.attachedCommands = attachedCommands
        self.timestamp = Date()
        self.suggestedCommand = suggestedCommand
        self.executedCommands = executedCommands
        self.pendingRiskyCommand = pendingRiskyCommand
    }
    
    init(id: UUID, prompt: String, response: String, attachedCommands: [AIAttachedCommand], suggestedCommand: String?, executedCommands: [AIExecutedCommand] = [], pendingRiskyCommand: String? = nil) {
        self.id = id
        self.prompt = prompt
        self.response = response
        self.attachedCommands = attachedCommands
        self.timestamp = Date()
        self.suggestedCommand = suggestedCommand
        self.executedCommands = executedCommands
        self.pendingRiskyCommand = pendingRiskyCommand
    }
}

// MARK: - AI Context Manager

@MainActor
class AIContextManager: ObservableObject {
    @Published var isAIMode = false // Keep internal name for simplicity
    @Published var attachedCommands: [AIAttachedCommand] = []
    @Published var conversationHistory: [AIConversationEntry] = []
    private var contextResetPoint: Int = 0 // Track where to start context from
    @Published var isProcessing = false
    @Published var lastError: String?
    @Published var lastSuggestedCommand: String = ""
    @Published var isExecutingCommands = false // AI is autonomously executing commands
    @Published var currentExecutionCommands: [AIExecutedCommand] = []
    
    // Contextual information cache
    private var cachedDirectoryListing: String = "" // Commands being executed in current session
    
    private let geminiClient = GeminiClient.shared
    weak var terminalSession: TerminalSession?
    
    // MARK: - AI Mode Management
    
    func toggleAIMode() {
        print("🔄 [DEBUG] toggleAIMode() called, current state: \(isAIMode)")
        isAIMode.toggle()
        print("🔄 [DEBUG] AI mode toggled to: \(isAIMode)")
        if !isAIMode {
            print("🔄 [DEBUG] AI mode disabled, marking context reset point")
            // Set context reset point to exclude older conversations from context
            // but keep them visible in UI
            contextResetPoint = max(0, conversationHistory.count - 1)
            print("🔄 [DEBUG] Set context reset point to \(contextResetPoint), keeping \(conversationHistory.count) visible conversations")
            // Clear active state
            clearActiveState()
        }
    }
    
    func enterAIMode() {
        isAIMode = true
    }
    
    func exitAIMode() {
        isAIMode = false
        print("🔄 [DEBUG] AI mode exited, marking context reset point")
        // Set context reset point to exclude older conversations from context
        // but keep them visible in UI
        contextResetPoint = max(0, conversationHistory.count - 1)
        print("🔄 [DEBUG] Set context reset point to \(contextResetPoint), keeping \(conversationHistory.count) visible conversations")
        clearActiveState()
    }
    
    func clearActiveState() {
        // Clear only the active working state, preserve conversation history
        attachedCommands.removeAll()
        lastError = nil
        currentExecutionCommands.removeAll()
        isExecutingCommands = false
        cachedDirectoryListing = ""
    }
    
    func clearAllHistory() {
        // Clear everything including conversation history (for complete reset)
        // This should only be called when user explicitly wants to reset everything
        attachedCommands.removeAll()
        conversationHistory.removeAll()
        contextResetPoint = 0
        lastError = nil
        currentExecutionCommands.removeAll()
        isExecutingCommands = false
        cachedDirectoryListing = ""
    }
    
    func clearContext() {
        // Legacy method - now just calls clearActiveState for safer behavior
        clearActiveState()
    }
    
    // MARK: - Autonomous Command Execution
    
    func executeCommandAutonomously(_ command: String) async {
        guard let terminal = terminalSession else { return }
        
        let isRisky = assessCommandRisk(command)
        
        if isRisky {
            // Add risky command to pending list for user approval
            if let lastEntry = conversationHistory.last {
                let updatedEntry = AIConversationEntry(
                    id: lastEntry.id, // Preserve the original UUID
                    prompt: lastEntry.prompt,
                    response: lastEntry.response,
                    attachedCommands: lastEntry.attachedCommands,
                    suggestedCommand: lastEntry.suggestedCommand,
                    executedCommands: lastEntry.executedCommands,
                    pendingRiskyCommand: command
                )
                conversationHistory[conversationHistory.count - 1] = updatedEntry
            }
            return
        }
        
        // Execute safe command automatically
        isExecutingCommands = true
        
        // Execute the command
        let result = await executeCommandAndCaptureOutput(command, terminal: terminal)
        
        let executedCommand = AIExecutedCommand(
            command: command,
            output: result.output,
            error: result.error,
            isRisky: isRisky,
            wasAutoExecuted: true,
            directory: terminal.currentDirectory
        )
        
        currentExecutionCommands.append(executedCommand)
        
        // Update the latest conversation entry with the new executed command
        if !conversationHistory.isEmpty {
            let lastIndex = conversationHistory.count - 1
            let originalEntry = conversationHistory[lastIndex]
            let updatedEntry = AIConversationEntry(
                id: originalEntry.id, // Preserve the original UUID
                prompt: originalEntry.prompt,
                response: originalEntry.response,
                attachedCommands: originalEntry.attachedCommands,
                suggestedCommand: originalEntry.suggestedCommand,
                executedCommands: originalEntry.executedCommands + [executedCommand],
                pendingRiskyCommand: originalEntry.pendingRiskyCommand
            )
            conversationHistory[lastIndex] = updatedEntry
        }
        
        // If there was an error, let AI analyze and potentially retry
        if result.error != nil {
            await analyzeErrorAndRetry(executedCommand)
        } else {
            // Command succeeded - check if we should continue with the task
            await continueTaskIfNeeded(executedCommand)
        }
        
        isExecutingCommands = false
    }
    
    func approveRiskyCommand(_ command: String) async {
        guard let terminal = terminalSession else { return }
        
        isExecutingCommands = true
        
        let result = await executeCommandAndCaptureOutput(command, terminal: terminal)
        
        let executedCommand = AIExecutedCommand(
            command: command,
            output: result.output,
            error: result.error,
            isRisky: true,
            wasAutoExecuted: false,
            directory: terminal.currentDirectory
        )
        
        currentExecutionCommands.append(executedCommand)
        
        // Update the latest conversation entry with the new executed command and clear pending
        if !conversationHistory.isEmpty {
            let lastIndex = conversationHistory.count - 1
            let originalEntry = conversationHistory[lastIndex]
            let updatedEntry = AIConversationEntry(
                id: originalEntry.id, // Preserve the original UUID
                prompt: originalEntry.prompt,
                response: originalEntry.response,
                attachedCommands: originalEntry.attachedCommands,
                suggestedCommand: originalEntry.suggestedCommand,
                executedCommands: originalEntry.executedCommands + [executedCommand],
                pendingRiskyCommand: nil
            )
            conversationHistory[lastIndex] = updatedEntry
        }
        
        // If there was an error, let AI analyze and potentially retry
        if result.error != nil {
            await analyzeErrorAndRetry(executedCommand)
        } else {
            // Command succeeded - check if we should continue with the task
            await continueTaskIfNeeded(executedCommand)
        }
        
        isExecutingCommands = false
    }
    
    private func assessCommandRisk(_ command: String) -> Bool {
        let riskyPatterns = [
            // Destructive deletion commands
            "rm -rf",
            "rm -fr", 
            "sudo rm",
            "rm /",
            "del /",
            "rmdir /s",
            
            // Permission changes that could compromise security
            "chmod 777",
            "chmod -R 777",
            "chmod a+rwx",
            "chown -R",
            
            // System administration commands
            "sudo",
            "doas",
            "su ",
            
            // Disk/filesystem operations
            "format",
            "fdisk",
            "dd if=",
            "dd of=",
            "mkfs",
            "wipefs",
            "parted",
            
            // Network operations that execute code
            "curl.*|.*sh",
            "wget.*|.*sh",
            "curl.*|.*bash",
            "wget.*|.*bash",
            "> /dev/",
            
            // Package management with elevated privileges
            "apt install",
            "yum install", 
            "dnf install",
            "pacman -S",
            "brew install",
            "pip install",
            "npm install -g",
            
            // Process/service management
            "systemctl",
            "service ",
            "launchctl",
            "kill -9",
            "killall",
            
            // File operations outside current directory
            "mv /",
            "cp .* /",
            "rsync .* /",
            
            // Database operations
            "DROP TABLE",
            "DROP DATABASE",
            "DELETE FROM",
            "TRUNCATE"
        ]
        
        let lowercaseCommand = command.lowercased()
        return riskyPatterns.contains { pattern in
            if pattern.contains(".*") {
                // Use regex for patterns with wildcards
                do {
                    let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                    let range = NSRange(location: 0, length: command.count)
                    return regex.firstMatch(in: command, options: [], range: range) != nil
                } catch {
                    // Fallback to simple contains if regex fails
                    return lowercaseCommand.contains(pattern.lowercased().replacingOccurrences(of: ".*", with: ""))
                }
            } else {
                return lowercaseCommand.contains(pattern.lowercased())
            }
        }
    }
    
    private func executeCommandAndCaptureOutput(_ command: String, terminal: TerminalSession) async -> (output: String, error: String?) {
        // Execute ALL commands through the main terminal session to preserve state
        // but capture outputs without showing them in the visible terminal
        return await terminal.executeCommandForAI(command)
    }
    
    private func analyzeErrorAndRetry(_ failedCommand: AIExecutedCommand) async {
        // Build context for AI to analyze the error and suggest a retry
        let errorContext = """
        Command failed: \(failedCommand.command)
        Error: \(failedCommand.error ?? "Unknown error")
        Output: \(failedCommand.output)
        Directory: \(failedCommand.directory)
        
        Please analyze this error and suggest a corrected command if possible. If you need more information, suggest diagnostic commands to run first.
        """
        
        // Let AI analyze and potentially suggest a retry
        await executeAIPrompt(errorContext)
    }
    
    private func continueTaskIfNeeded(_ successfulCommand: AIExecutedCommand) async {
        // Get the latest entry which contains the original user prompt and context
        guard let lastEntry = conversationHistory.last else { return }
        
        // Don't continue if this was already a retry/continuation to avoid infinite loops
        let executedCommands = lastEntry.executedCommands
        if executedCommands.count >= 3 {
            print("🤖 [DEBUG] Stopping autonomous execution after 3 commands to prevent infinite loops")
            return
        }
        
        // Build context about what we accomplished and ask if we should continue
        let contextPrompt = """
        I just successfully executed: '\(successfulCommand.command)'
        Output: \(successfulCommand.output)
        Current directory: \(successfulCommand.directory)
        
        Original user request: \(lastEntry.prompt)
        
        Based on the output and the original request, do I need to execute additional commands to complete the user's goal? If yes, suggest the next command to execute.
        """
        
        // Get AI response for next step WITHOUT creating a new conversation entry
        do {
            print("🤖 [DEBUG] Asking AI for next step in task continuation...")
            let action = try await sendActionPrompt(contextPrompt)
            print("🤖 [DEBUG] AI continuation response: \(action.explanation)")
            print("🤖 [DEBUG] Next suggested command: '\(action.suggestedCommand)'")
            print("🤖 [DEBUG] AutoExecute flag: \(action.autoExecute)")
            
            // If AI suggests another command and wants to auto-execute it, do so
            if !action.suggestedCommand.isEmpty && action.autoExecute {
                print("🤖 [DEBUG] Continuing autonomous execution with: '\(action.suggestedCommand)'")
                await executeCommandAutonomously(action.suggestedCommand)
            } else {
                print("🤖 [DEBUG] Task continuation complete - no more commands needed")
            }
        } catch {
            print("🤖 [ERROR] Failed to get AI continuation response: \(error)")
        }
    }
    
    // MARK: - Context Attachment
    
    func attachLatestCommand(from outputs: [TerminalOutput]) {
        guard let lastCommandIndex = findLastCommandIndex(in: outputs) else { return }
        
        let commandOutput = outputs[lastCommandIndex]
        let followingOutputs = getOutputsAfterCommand(at: lastCommandIndex, in: outputs)
        
        let attachedCommand = AIAttachedCommand(from: commandOutput, commandOutput: followingOutputs)
        
        // Avoid duplicates
        if !attachedCommands.contains(where: { $0.command == attachedCommand.command && $0.timestamp == attachedCommand.timestamp }) {
            attachedCommands.append(attachedCommand)
            // Auto-enable Agent mode when context is attached
            isAIMode = true
        }
    }
    
    func removeAttachedCommand(_ command: AIAttachedCommand) {
        attachedCommands.removeAll { $0.id == command.id }
    }
    
    // MARK: - Contextual Information Gathering
    
    private func gatherContextualInfo() async {
        guard let terminal = terminalSession else { return }
        
        print("🤖 [DEBUG] Gathering contextual information...")
        
        // Get current directory listing with details
        let result = await terminal.executeCommandSilently("ls -lAh")
        if result.error == nil {
            cachedDirectoryListing = result.output
            print("🤖 [DEBUG] Cached directory listing (\(result.output.count) chars)")
        } else {
            cachedDirectoryListing = "Error getting directory listing: \(result.error ?? "Unknown error")"
            print("🤖 [DEBUG] Failed to get directory listing: \(result.error ?? "Unknown")")
        }
    }
    
    // MARK: - AI Prompt Execution
    
    func executeAIPrompt(_ prompt: String) async {
        print("🤖 [DEBUG] executeAIPrompt() called with: '\(prompt)'")
        
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { 
            print("🤖 [DEBUG] Empty prompt, returning early")
            return 
        }
        
        print("🤖 [DEBUG] Starting AI processing...")
        isProcessing = true
        lastError = nil
        
        // Clear execution commands from previous conversations - each conversation should start fresh
        currentExecutionCommands.removeAll()
        print("🤖 [DEBUG] Cleared previous execution commands, starting fresh conversation")
        
        do {
            // Gather contextual information before sending to AI
            await gatherContextualInfo()
            
            print("🤖 [DEBUG] Sending action prompt to AI...")
            let action = try await sendActionPrompt(prompt)
            print("🤖 [DEBUG] AI response received: \(action.explanation)")
            print("🤖 [DEBUG] Raw AI response - autoExecute: \(action.autoExecute), command: '\(action.suggestedCommand)', risk: \(action.risk)")
            print("🤖 [DEBUG] User prompt was: '\(prompt)'")
            print("🤖 [DEBUG] Has attached commands: \(!attachedCommands.isEmpty)")
            print("🤖 [DEBUG] Conversation history count: \(conversationHistory.count)")
            
            let responseText = renderActionForDisplay(action)
            lastSuggestedCommand = action.suggestedCommand
            print("🤖 [DEBUG] Suggested command: '\(action.suggestedCommand)'")
            
            // Store attached commands for this conversation entry, then clear them
            let conversationAttachedCommands = attachedCommands
            print("🤖 [DEBUG] Creating conversation entry with \(conversationAttachedCommands.count) attached commands")
            
            // Create conversation entry with the attached commands (if any)
            let conversationEntry = AIConversationEntry(
                prompt: prompt, 
                response: responseText, 
                attachedCommands: conversationAttachedCommands, 
                suggestedCommand: action.suggestedCommand,
                executedCommands: currentExecutionCommands
            )
            conversationHistory.append(conversationEntry)
            print("🤖 [DEBUG] Added conversation entry, total history: \(conversationHistory.count)")
            print("🤖 [DEBUG] New entry has \(conversationEntry.attachedCommands.count) attached commands")
            print("🤖 [DEBUG] New entry isEmpty filter result: \(conversationEntry.attachedCommands.isEmpty)")
            
            // Add AI response as a terminal output entry so it appears in the main terminal flow
            terminalSession?.addAIResponse(conversationEntry)
            
            // Clear attached commands after creating the conversation entry to avoid clutter in future entries
            attachedCommands.removeAll()
            print("🤖 [DEBUG] Cleared attached commands")
            
            // ALWAYS autonomously execute commands - no more suggested commands
            // Only skip execution if the command is empty
            if !action.suggestedCommand.isEmpty {
                print("🤖 [DEBUG] Autonomously executing command: '\(action.suggestedCommand)'")
                await executeCommandAutonomously(action.suggestedCommand)
            } else {
                print("🤖 [DEBUG] No command to execute from AI response")
            }
            
            // Clear current execution commands (they're now part of the conversation history)
            currentExecutionCommands.removeAll()
            
        } catch {
            print("🤖 [DEBUG] AI processing error: \(error.localizedDescription)")
            lastError = error.localizedDescription
        }
        
        print("🤖 [DEBUG] AI processing completed")
        isProcessing = false
    }
    
    private func sendActionPrompt(_ prompt: String) async throws -> GeminiClient.AgentAction {
        let systemPrompt = buildSystemPrompt()
        let userPrompt = buildUserPrompt(prompt)
        let fullPrompt = systemPrompt + "\n\n" + userPrompt
        return try await geminiClient.generateAction(prompt: fullPrompt)
    }

    private func renderActionForDisplay(_ a: GeminiClient.AgentAction) -> String {
        var lines: [String] = []
        if !a.explanation.isEmpty { lines.append(a.explanation) }
        if !a.suggestedCommand.isEmpty { lines.append("Suggested: " + a.suggestedCommand) }
        if !a.alternatives.isEmpty { lines.append("Alternatives: " + a.alternatives.joined(separator: " | ")) }
        if !a.notes.isEmpty { lines.append("Notes: " + a.notes.joined(separator: " | ")) }
        if !a.risk.isEmpty { lines.append("Risk: " + a.risk) }
        lines.append("ConfirmRequired: \(a.requiresConfirmation ? "yes" : "no")")
        return lines.joined(separator: "\n")
    }
    
    private func buildSystemPrompt() -> String {
        // Conversational terminal assistant like ChatGPT with autonomous execution
        return """
        You are an expert terminal assistant integrated into the nux terminal application.
        You help users with terminal commands, debugging, and system tasks.
        
        CONTEXTUAL AWARENESS:
        - You receive detailed context about the current directory (ls -lAh output)
        - You know the current OS, shell, and environment variables
        - You can see recent terminal history and attached command contexts
        - Use this information to provide accurate, context-aware responses
        
        AUTONOMOUS EXECUTION MODE:
        - You can execute commands autonomously to gather information and solve problems
        - Safe commands (ls, pwd, cat, grep, etc.) will be executed automatically
        - Risky commands (rm, sudo, chmod 777, etc.) will require user approval
        - You can execute multiple commands in sequence to solve complex problems
        - All executed commands and their outputs become part of the context
        
        CRITICAL - AUTONOMOUS EXECUTION (MANDATORY RULES):
        - ALL suggested commands will be executed autonomously - no user interaction required
        - Only high-risk commands (rm -rf, sudo, etc.) will require user approval via approval UI
        - For questions/explanations, provide conversational responses but no commands
        - For actions, ALWAYS provide a command that will be executed automatically
        - Set autoExecute=true for ALL commands (this field is now informational only)
        - NEVER suggest commands that you don't want executed immediately
        - High-risk commands will be caught by the risk assessment system and show approval UI
        
        You can help with:
        1. Fixing command errors (when context is provided)
        2. General terminal questions and guidance
        3. Explaining commands and their usage
        4. Suggesting commands for specific tasks
        5. Debugging system issues
        6. Autonomously executing diagnostic commands to gather information
        
        WORKFLOW:
        1. If user wants you to DO something, suggest the appropriate command that will be auto-executed
        2. If user asks general questions, provide helpful explanations without commands
        3. Analyze the results and suggest next steps when commands are executed
        4. Continue iteratively until the user's goal is fully accomplished
        
        TASK COMPLETION:
        - When continuing a task, analyze if the user's original goal has been achieved
        - If a command like 'ls' reveals available options, automatically proceed with the correct command (e.g., 'cd Users/')
        - Complete multi-step tasks autonomously (e.g., 'navigate to users' = 'ls -F' + 'cd Users/')
        - Stop execution when the task is complete or after 3 commands to prevent loops
        
        Be conversational and helpful, like ChatGPT. You can ask follow-up questions if needed.
        Always provide suggested commands in a copyable format when relevant.
        
        Structure your responses with clear sections when appropriate:
        - Use "Explanation:" for the main analysis
        - Use "Suggested:" for the primary command to run
        - Use "Notes:" for additional helpful information
        - Use "Risk:" for safety warnings
        - Use "Alternatives:" for other command options
        
        Return strictly plain text JSON (no markdown fences, no backticks, no extra commentary):
        {
          "explanation": "conversational explanation or response to the user's question",
          "suggestedCommand": "single-line shell command to run, or empty string if none",
          "autoExecute": true|false,
          "alternatives": ["optional other commands"],
          "notes": ["optional helpful tips"],
          "risk": "low|medium|high",
          "requiresConfirmation": true|false
        }
        """
    }
    
    private func buildUserPrompt(_ prompt: String) -> String {
        var lines: [String] = []
        lines.append("UserQuery: \(prompt)")
        
        // OS / shell / cwd context
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let shell = "/bin/zsh"
        let cwd = terminalSession?.currentDirectory ?? FileManager.default.currentDirectoryPath
        lines.append("OS: \(osVersion)")
        lines.append("Shell: \(shell)")
        lines.append("CWD: \(cwd)")
        
        // Add current directory listing for context
        if !cachedDirectoryListing.isEmpty {
            lines.append("DirectoryContents:")
            lines.append(cachedDirectoryListing)
        }
        
        // Environment snapshot (sample/top variables to keep length reasonable)
        if let env = terminalSession?.environmentSnapshot() {
            let keys = ["PATH","HOME","SHELL","USER","LANG"]
            let envPairs = keys.compactMap { key in env[key].map { "\(key)=\($0)" } }
            if !envPairs.isEmpty { lines.append("Env: \(envPairs.joined(separator: "; "))") }
        }
        
        // Include last N outputs
        if let session = terminalSession {
            let N = 20
            let transcriptLines: [String] = session.outputs.suffix(N).map { out in
                let pfx: String
                switch out.type {
                case .command: pfx = "CMD $"
                case .output: pfx = "OUT"
                case .error: pfx = "ERR"
                case .success: pfx = "OK"
                case .aiResponse: pfx = "AI"
                }
                return "\(pfx) \(out.text)"
            }
            if !transcriptLines.isEmpty {
                lines.append("Recent: \n" + transcriptLines.joined(separator: "\n"))
            }
        }
        
        // Attached command contexts
        if !attachedCommands.isEmpty {
            lines.append("AttachedContexts:")
            for command in attachedCommands {
                lines.append(command.contextString)
            }
        }
        
        // Guidance
        if !attachedCommands.isEmpty {
            lines.append("Be conversational and helpful. If the user says 'Fix this', analyze the attached command context and provide a clear explanation and solution.")
            lines.append("CRITICAL: ALL corrective commands will be executed automatically.")
        } else {
            lines.append("Be conversational and helpful. Provide general terminal assistance and guidance.")
            lines.append("CRITICAL: ALL action commands will be executed automatically.")
        }
        
        // Autonomous execution guidance
        lines.append("AUTONOMOUS EXECUTION RULES:")
        lines.append("- USER REQUEST: '\(prompt)' - ANALYZE THIS CAREFULLY!")
        lines.append("- ALL commands will be executed automatically - no user interaction required")
        lines.append("- For actions: Provide the appropriate command, it will execute immediately")
        lines.append("- For questions: Provide explanations without commands")
        lines.append("- RISKY commands will be caught by risk assessment and require user approval")
        lines.append("- ALWAYS set autoExecute=true for ANY command you suggest")
        lines.append("- NEVER suggest commands unless you want them executed immediately")
        lines.append("- System will handle risk assessment - focus on providing the right commands")
        
        lines.append("Set requiresConfirmation=true for destructive operations (rm -rf, sudo, chmod -R 777, etc.) or when writing outside CWD.")
        return lines.joined(separator: "\n")
    }
    
    // MARK: - Helper Methods
    
    private func isActionPrompt(_ prompt: String) -> Bool {
        let actionKeywords = [
            "go", "navigate", "list", "show", "count", "find", "create", "make", 
            "move", "copy", "search", "check", "display", "run", "execute", 
            "back", "parent", "into", "to", "from", "with", "using"
        ]
        
        let questionKeywords = [
            "why", "how", "what", "explain", "describe", "tell me about", 
            "what is", "how does", "why does", "when", "where"
        ]
        
        let lowercasedPrompt = prompt.lowercased()
        
        // Check for action keywords
        let hasActionKeyword = actionKeywords.contains { keyword in
            lowercasedPrompt.contains(keyword)
        }
        
        // Check for question keywords
        let hasQuestionKeyword = questionKeywords.contains { keyword in
            lowercasedPrompt.contains(keyword)
        }
        
        // If it has action keywords and no question keywords, it's an action request
        let isAction = hasActionKeyword && !hasQuestionKeyword
        print("🤖 [DEBUG] Action detection - prompt: '\(prompt)', hasAction: \(hasActionKeyword), hasQuestion: \(hasQuestionKeyword), isAction: \(isAction)")
        return isAction
    }
    
    private func findLastCommandIndex(in outputs: [TerminalOutput]) -> Int? {
        for i in (0..<outputs.count).reversed() {
            if outputs[i].type == .command {
                return i
            }
        }
        return nil
    }
    
    private func getOutputsAfterCommand(at commandIndex: Int, in outputs: [TerminalOutput]) -> [TerminalOutput] {
        let startIndex = commandIndex + 1
        guard startIndex < outputs.count else { return [] }
        
        var result: [TerminalOutput] = []
        
        for i in startIndex..<outputs.count {
            let output = outputs[i]
            if output.type == .command {
                break // Stop at next command
            }
            result.append(output)
        }
        
        return result
    }
    
    // MARK: - Context Information
    
    var hasContext: Bool {
        !attachedCommands.isEmpty || !conversationHistory.isEmpty
    }
    
    var contextSummary: String {
        var parts: [String] = []
        
        if !attachedCommands.isEmpty {
            parts.append("\(attachedCommands.count) attachment\(attachedCommands.count == 1 ? "" : "s")")
        }
        
        if !conversationHistory.isEmpty {
            parts.append("\(conversationHistory.count) conversation\(conversationHistory.count == 1 ? "" : "s")")
        }
        
        return parts.joined(separator: ", ")
    }
}
