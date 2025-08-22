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

struct AIConversationEntry: Codable, Identifiable {
    let id = UUID()
    let prompt: String
    let response: String
    let timestamp: Date
    let attachedCommands: [AIAttachedCommand]
    
    init(prompt: String, response: String, attachedCommands: [AIAttachedCommand]) {
        self.prompt = prompt
        self.response = response
        self.attachedCommands = attachedCommands
        self.timestamp = Date()
    }
}

// MARK: - AI Context Manager

@MainActor
class AIContextManager: ObservableObject {
    @Published var isAIMode = false // Keep internal name for simplicity
    @Published var attachedCommands: [AIAttachedCommand] = []
    @Published var conversationHistory: [AIConversationEntry] = []
    @Published var currentPrompt = ""
    @Published var isProcessing = false
    @Published var lastError: String?
    
    private let geminiClient = GeminiClient.shared
    
    // MARK: - AI Mode Management
    
    func toggleAIMode() {
        isAIMode.toggle()
        if !isAIMode {
            clearContext()
        }
    }
    
    func enterAIMode() {
        isAIMode = true
    }
    
    func exitAIMode() {
        isAIMode = false
        clearContext()
    }
    
    func clearContext() {
        attachedCommands.removeAll()
        conversationHistory.removeAll()
        currentPrompt = ""
        lastError = nil
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
    
    // MARK: - AI Prompt Execution
    
    func executeAIPrompt(_ prompt: String) async {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isProcessing = true
        lastError = nil
        
        do {
            let response = try await sendPromptToAI(prompt)
            
            let conversationEntry = AIConversationEntry(
                prompt: prompt,
                response: response,
                attachedCommands: attachedCommands
            )
            
            conversationHistory.append(conversationEntry)
            currentPrompt = ""
            
        } catch {
            lastError = error.localizedDescription
        }
        
        isProcessing = false
    }
    
    private func sendPromptToAI(_ prompt: String) async throws -> String {
        let systemPrompt = buildSystemPrompt()
        let userPrompt = buildUserPrompt(prompt)
        let fullPrompt = systemPrompt + "\n\n" + userPrompt
        
        let response = try await geminiClient.generateResponse(prompt: fullPrompt)
        return response
    }
    
    private func buildSystemPrompt() -> String {
        return """
        You are an expert terminal assistant integrated into the nux terminal application. 
        You help users understand their terminal sessions, debug issues, and suggest commands.
        
        Guidelines:
        - Provide clear, actionable advice
        - Suggest specific commands when appropriate
        - Explain technical concepts simply
        - Focus on practical solutions
        - Consider the user's current directory and recent command context
        
        If commands are attached as context, use that information to provide more relevant assistance.
        Be concise but thorough in your responses.
        """
    }
    
    private func buildUserPrompt(_ prompt: String) -> String {
        var fullPrompt = "User Query: \(prompt)\n"
        
        if !attachedCommands.isEmpty {
            fullPrompt += "\nAttached Command Context:\n"
            for command in attachedCommands {
                fullPrompt += "\n--- Command Context ---\n"
                fullPrompt += command.contextString
                fullPrompt += "\n"
            }
        }
        
        if !conversationHistory.isEmpty {
            fullPrompt += "\nPrevious Conversation History:\n"
            for entry in conversationHistory.suffix(3) { // Include last 3 entries for context
                fullPrompt += "\nUser: \(entry.prompt)"
                fullPrompt += "\nAssistant: \(entry.response)\n"
            }
        }
        
        return fullPrompt
    }
    
    // MARK: - Helper Methods
    
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
            parts.append("\(attachedCommands.count) attached command\(attachedCommands.count == 1 ? "" : "s")")
        }
        
        if !conversationHistory.isEmpty {
            parts.append("\(conversationHistory.count) conversation\(conversationHistory.count == 1 ? "" : "s")")
        }
        
        return parts.joined(separator: ", ")
    }
}
