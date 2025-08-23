import Foundation

// MARK: - Common LLM Models

struct SessionSummary: Codable {
    let summary: String
    let commands: [String]
    let errors: [String]
    let nextSteps: [String]
    let keyInsights: [String]
    let potentialIssues: [String]
    let usefulCommands: [String]
    let currentState: String
    let recommendations: [String]
}

struct AgentAction: Codable {
    let explanation: String
    let suggestedCommand: String
    let autoExecute: Bool
    let alternatives: [String]
    let notes: [String]
    let risk: String
    let requiresConfirmation: Bool
}

// MARK: - LLM Provider Protocol

enum LLMError: Error, LocalizedError {
    case missingConfiguration
    case invalidResponse
    case network(Error)
    case message(String)
    case serviceUnavailable
    
    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "LLM provider not properly configured. Check settings."
        case .invalidResponse:
            return "Invalid response from LLM provider."
        case .network(let err):
            return err.localizedDescription
        case .message(let text):
            return text
        case .serviceUnavailable:
            return "LLM service is currently unavailable."
        }
    }
}

enum LLMProviderType: String, CaseIterable {
    case gemini = "gemini"
    case ollama = "ollama"
    
    var displayName: String {
        switch self {
        case .gemini:
            return "Google Gemini"
        case .ollama:
            return "Ollama (Local)"
        }
    }
    
    var requiresApiKey: Bool {
        switch self {
        case .gemini:
            return true
        case .ollama:
            return false
        }
    }
    
    var isLocal: Bool {
        switch self {
        case .gemini:
            return false
        case .ollama:
            return true
        }
    }
}

protocol LLMProvider {
    var providerType: LLMProviderType { get }
    var isConfigured: Bool { get }
    var isAvailable: Bool { get async }
    
    func summarize(outputs: [TerminalOutput]) async throws -> String
    func summarizeStructured(outputs: [TerminalOutput]) async throws -> SessionSummary
    func generateAction(prompt: String) async throws -> AgentAction
    func generateResponse(prompt: String) async throws -> String
}

// MARK: - LLM Manager

@MainActor
class LLMManager: ObservableObject {
    @Published var currentProvider: LLMProviderType = .ollama
    @Published var availableProviders: [LLMProviderType] = []
    
    private var providers: [LLMProviderType: LLMProvider] = [:]
    private let userDefaultsKey = "SelectedLLMProvider"
    
    static let shared = LLMManager()
    
    private init() {
        // Initialize providers
        providers[.gemini] = GeminiLLMProvider()
        providers[.ollama] = OllamaLLMProvider()
        
        // Load saved provider preference
        if let savedProvider = UserDefaults.standard.string(forKey: userDefaultsKey),
           let providerType = LLMProviderType(rawValue: savedProvider) {
            currentProvider = providerType
        }
        
        // Check which providers are available
        Task {
            await updateAvailableProviders()
        }
    }
    
    func updateAvailableProviders() async {
        var available: [LLMProviderType] = []
        
        for (type, provider) in providers {
            let isAvailable = await provider.isAvailable
            if provider.isConfigured && isAvailable {
                available.append(type)
            }
        }
        
        await MainActor.run {
            self.availableProviders = available
            
            // If current provider is not available, switch to first available
            if !available.contains(currentProvider) && !available.isEmpty {
                self.currentProvider = available[0]
                self.saveProviderPreference()
            }
        }
    }
    
    func setProvider(_ providerType: LLMProviderType) {
        guard availableProviders.contains(providerType) else { return }
        currentProvider = providerType
        saveProviderPreference()
    }
    
    private func saveProviderPreference() {
        UserDefaults.standard.set(currentProvider.rawValue, forKey: userDefaultsKey)
    }
    
    var activeProvider: LLMProvider? {
        return providers[currentProvider]
    }
    
    // MARK: - Provider Methods (Delegate to active provider)
    
    func summarize(outputs: [TerminalOutput]) async throws -> String {
        guard let provider = activeProvider else {
            throw LLMError.serviceUnavailable
        }
        return try await provider.summarize(outputs: outputs)
    }
    
    func summarizeStructured(outputs: [TerminalOutput]) async throws -> SessionSummary {
        guard let provider = activeProvider else {
            throw LLMError.serviceUnavailable
        }
        return try await provider.summarizeStructured(outputs: outputs)
    }
    
    func generateAction(prompt: String) async throws -> AgentAction {
        guard let provider = activeProvider else {
            throw LLMError.serviceUnavailable
        }
        return try await provider.generateAction(prompt: prompt)
    }
    
    func generateResponse(prompt: String) async throws -> String {
        guard let provider = activeProvider else {
            throw LLMError.serviceUnavailable
        }
        return try await provider.generateResponse(prompt: prompt)
    }
}
