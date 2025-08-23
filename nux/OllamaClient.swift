import Foundation

// MARK: - Ollama Client

class OllamaLLMProvider: LLMProvider {
    let providerType: LLMProviderType = .ollama
    
    private let baseURL = "http://localhost:11434"
    private let defaultModel = "llama3.1:8b"
    private let modelKey = "OllamaModel"
    
    var isConfigured: Bool {
        // Ollama doesn't require API keys, just needs to be running
        return true
    }
    
    var isAvailable: Bool {
        get async {
            await checkOllamaAvailability()
        }
    }
    
    var selectedModel: String {
        get {
            UserDefaults.standard.string(forKey: modelKey) ?? defaultModel
        }
        set {
            UserDefaults.standard.set(newValue, forKey: modelKey)
        }
    }
    
    // MARK: - Ollama API Models
    
    private struct OllamaGenerateRequest: Codable {
        let model: String
        let prompt: String
        let stream: Bool = false
        let options: Options?
        
        struct Options: Codable {
            let temperature: Double?
            let top_p: Double?
            let max_tokens: Int?
            
            init(temperature: Double = 0.7, topP: Double = 0.9, maxTokens: Int = 2048) {
                self.temperature = temperature
                self.top_p = topP
                self.max_tokens = maxTokens
            }
        }
    }
    
    private struct OllamaGenerateResponse: Codable {
        let model: String
        let response: String
        let done: Bool
        let context: [Int]?
        let total_duration: Int?
        let load_duration: Int?
        let prompt_eval_count: Int?
        let prompt_eval_duration: Int?
        let eval_count: Int?
        let eval_duration: Int?
    }
    
    private struct OllamaListResponse: Codable {
        let models: [OllamaModel]
        
        struct OllamaModel: Codable {
            let name: String
            let size: Int
            let digest: String
            let modified_at: String
        }
    }
    
    // MARK: - API Methods
    
    private func checkOllamaAvailability() async -> Bool {
        do {
            guard let url = URL(string: "\(baseURL)/api/tags") else { return false }
            
            var request = URLRequest(url: url)
            request.timeoutInterval = 5.0
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            return false
        }
    }
    
    func getAvailableModels() async throws -> [String] {
        guard let url = URL(string: "\(baseURL)/api/tags") else {
            throw LLMError.invalidResponse
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw LLMError.serviceUnavailable
        }
        
        let listResponse = try JSONDecoder().decode(OllamaListResponse.self, from: data)
        return listResponse.models.map { $0.name }
    }
    
    private func generateText(prompt: String, temperature: Double = 0.7) async throws -> String {
        guard let url = URL(string: "\(baseURL)/api/generate") else {
            throw LLMError.invalidResponse
        }
        
        let requestBody = OllamaGenerateRequest(
            model: selectedModel,
            prompt: prompt,
            options: OllamaGenerateRequest.Options(temperature: temperature)
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw LLMError.invalidResponse
            }
            
            if httpResponse.statusCode != 200 {
                let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw LLMError.message("Ollama error (\(httpResponse.statusCode)): \(errorText)")
            }
            
            let ollamaResponse = try JSONDecoder().decode(OllamaGenerateResponse.self, from: data)
            return ollamaResponse.response
            
        } catch {
            if error is LLMError {
                throw error
            } else {
                throw LLMError.network(error)
            }
        }
    }
    
    // MARK: - LLMProvider Implementation
    
    func summarize(outputs: [TerminalOutput]) async throws -> String {
        let prompt = buildSummaryPrompt(outputs: outputs)
        return try await generateText(prompt: prompt)
    }
    
    func summarizeStructured(outputs: [TerminalOutput]) async throws -> SessionSummary {
        let raw = try await summarize(outputs: outputs)
        return try parseSessionSummary(from: raw)
    }
    
    func generateAction(prompt: String) async throws -> AgentAction {
        let raw = try await generateResponse(prompt: prompt)
        return try parseAgentAction(from: raw)
    }
    
    func generateResponse(prompt: String) async throws -> String {
        return try await generateText(prompt: prompt)
    }
    
    // MARK: - Prompt Building
    
    private func buildSummaryPrompt(outputs: [TerminalOutput]) -> String {
        let maxLines = 120
        let transcriptLines: [String] = outputs.suffix(maxLines).map { out in
            let prefix: String
            switch out.type {
            case .command: prefix = "${\(out.prompt)} "
            case .output: prefix = ""
            case .error: prefix = "[error] "
            case .success: prefix = "[success] "
            case .aiResponse: prefix = "[ai] "
            }
            return prefix + out.text
        }
        let transcript = transcriptLines.joined(separator: "\n")
        
        return """
        You are an expert terminal session analyzer. Analyze this session and provide actionable insights.
        
        Return ONLY valid JSON with this exact schema, no markdown or extra text:
        {
          "summary": "Brief overview of what was accomplished",
          "commands": ["list of all commands executed"],
          "errors": ["any error messages or failed commands"],
          "nextSteps": ["immediate next actions the user should take"],
          "keyInsights": ["important discoveries, patterns, or learnings"],
          "potentialIssues": ["problems that might arise or need attention"],
          "usefulCommands": ["commands that were particularly helpful or worth remembering"],
          "currentState": "description of the current system state and working directory",
          "recommendations": ["specific suggestions for improvement or optimization"]
        }
        
        Focus on practical, actionable information that helps the user understand what happened and what to do next.
        Be specific and include actual commands, paths, and technical details when relevant.
        Do not include command lists in the summary - focus on insights and actionable information.
        Use plain text only - no markdown, no formatting, no special characters except basic punctuation.
        Keep it concise:
        - summary: max 2 short sentences, <= 220 characters
        - each list (errors/nextSteps/keyInsights/potentialIssues/usefulCommands/recommendations): up to 6 items
        - each item: short phrase, <= 80 characters
        - avoid long paragraphs; prefer terse, scannable lines
        
        Session transcript:
        |||
        \(transcript)
        |||
        """
    }
    
    // MARK: - Response Parsing
    
    private func parseSessionSummary(from raw: String) throws -> SessionSummary {
        guard let start = raw.firstIndex(of: "{"), let end = raw.lastIndex(of: "}") else {
            throw LLMError.invalidResponse
        }
        let json = String(raw[start...end])
        guard let data = json.data(using: .utf8) else { throw LLMError.invalidResponse }
        
        do {
            let decoded = try JSONDecoder().decode(SessionSummary.self, from: data)
            return normalize(summary: decoded)
        } catch {
            throw LLMError.invalidResponse
        }
    }
    
    private func parseAgentAction(from raw: String) throws -> AgentAction {
        guard let start = raw.firstIndex(of: "{"), let end = raw.lastIndex(of: "}") else {
            throw LLMError.invalidResponse
        }
        let json = String(raw[start...end])
        guard let data = json.data(using: .utf8) else { throw LLMError.invalidResponse }
        
        do {
            return try JSONDecoder().decode(AgentAction.self, from: data)
        } catch {
            throw LLMError.invalidResponse
        }
    }
    
    // MARK: - Post-processing
    
    private func normalize(summary s: SessionSummary) -> SessionSummary {
        let clampSummary = clampText(s.summary, maxChars: 220)
        let clampState = clampText(s.currentState, maxChars: 160)
        return SessionSummary(
            summary: clampSummary,
            commands: clampList(s.commands, maxItems: 6, maxChars: 80),
            errors: clampList(s.errors, maxItems: 6, maxChars: 80),
            nextSteps: clampList(s.nextSteps, maxItems: 6, maxChars: 80),
            keyInsights: clampList(s.keyInsights, maxItems: 6, maxChars: 80),
            potentialIssues: clampList(s.potentialIssues, maxItems: 6, maxChars: 80),
            usefulCommands: clampList(s.usefulCommands, maxItems: 6, maxChars: 80),
            currentState: clampState,
            recommendations: clampList(s.recommendations, maxItems: 6, maxChars: 80)
        )
    }
    
    private func clampList(_ arr: [String], maxItems: Int, maxChars: Int) -> [String] {
        if arr.isEmpty { return [] }
        return Array(arr.prefix(maxItems)).map { clampText($0, maxChars: maxChars) }
            .filter { !$0.isEmpty }
    }
    
    private func clampText(_ text: String, maxChars: Int) -> String {
        var t = text.replacingOccurrences(of: "\r", with: "")
        t = t.replacingOccurrences(of: "\n+", with: " ", options: .regularExpression)
        t = t.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        t = t.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.count > maxChars {
            let endIndex = t.index(t.startIndex, offsetBy: maxChars)
            return String(t[..<endIndex]).trimmingCharacters(in: .whitespaces) + "…"
        }
        return t
    }
}
