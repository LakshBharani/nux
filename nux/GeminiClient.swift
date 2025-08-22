import Foundation

enum GeminiError: Error, LocalizedError {
    case missingApiKey
    case invalidResponse
    case network(Error)
    case message(String)
    
    var errorDescription: String? {
        switch self {
        case .missingApiKey:
            return "Missing Gemini API key. Add it in Settings."
        case .invalidResponse:
            return "Invalid response from Gemini."
        case .network(let err):
            return err.localizedDescription
        case .message(let text):
            return text
        }
    }
}

final class GeminiClient {
    static let shared = GeminiClient()
    private init() {}
    
    private let model = "gemini-2.5-flash"
    private let endpointBase = "https://generativelanguage.googleapis.com/v1beta/models/"
    private let apiKeyDefaultsKey = "GeminiAPIKey"
    
    func getApiKey() -> String? {
        UserDefaults.standard.string(forKey: apiKeyDefaultsKey)
    }
    
    func setApiKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: apiKeyDefaultsKey)
    }
    
    struct GenerateRequest: Encodable {
        struct Content: Encodable { let role: String?; let parts: [Part] }
        struct Part: Encodable { let text: String }
        let contents: [Content]
    }
    
    struct GenerateResponse: Decodable { let candidates: [Candidate]? }
    struct Candidate: Decodable { let content: Content? }
    struct Content: Decodable { let parts: [Part]? }
    struct Part: Decodable { let text: String? }
    
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
    
    func summarize(outputs: [TerminalOutput]) async throws -> String {
        guard let apiKey = getApiKey(), apiKey.isEmpty == false else {
            throw GeminiError.missingApiKey
        }
        let urlString = "\(endpointBase)\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else { throw GeminiError.invalidResponse }
        
        let prompt = buildSummaryPrompt(outputs: outputs)
        let reqBody = GenerateRequest(contents: [
            .init(role: "user", parts: [.init(text: prompt)])
        ])
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(reqBody)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                if let text = String(data: data, encoding: .utf8), text.isEmpty == false {
                    throw GeminiError.message(text)
                }
                throw GeminiError.invalidResponse
            }
            let decoded = try JSONDecoder().decode(GenerateResponse.self, from: data)
            if let text = decoded.candidates?.first?.content?.parts?.compactMap({ $0.text }).joined(separator: "\n"), !text.isEmpty {
                return text
            }
            throw GeminiError.invalidResponse
        } catch {
            throw GeminiError.network(error)
        }
    }
    
    private func buildSummaryPrompt(outputs: [TerminalOutput]) -> String {
        let maxLines = 120
        let transcriptLines: [String] = outputs.suffix(maxLines).map { out in
            let prefix: String
            switch out.type {
            case .command: prefix = "${\(out.prompt)} "
            case .output: prefix = ""
            case .error: prefix = "[error] "
            case .success: prefix = "[success] "
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

    func summarizeStructured(outputs: [TerminalOutput]) async throws -> SessionSummary {
        let raw = try await summarize(outputs: outputs)
        guard let start = raw.firstIndex(of: "{"), let end = raw.lastIndex(of: "}") else {
            throw GeminiError.invalidResponse
        }
        let json = String(raw[start...end])
        guard let data = json.data(using: .utf8) else { throw GeminiError.invalidResponse }
        do {
            let decoded = try JSONDecoder().decode(SessionSummary.self, from: data)
            return normalize(summary: decoded)
        } catch {
            throw GeminiError.invalidResponse
        }
    }
    
    // MARK: - AI Assistant Methods
    
    func generateResponse(prompt: String) async throws -> String {
        guard let apiKey = getApiKey(), apiKey.isEmpty == false else {
            throw GeminiError.missingApiKey
        }
        let urlString = "\(endpointBase)\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else { throw GeminiError.invalidResponse }
        
        let reqBody = GenerateRequest(contents: [
            .init(role: "user", parts: [.init(text: prompt)])
        ])
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(reqBody)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                if let text = String(data: data, encoding: .utf8), text.isEmpty == false {
                    throw GeminiError.message(text)
                }
                throw GeminiError.invalidResponse
            }
            let decoded = try JSONDecoder().decode(GenerateResponse.self, from: data)
            if let text = decoded.candidates?.first?.content?.parts?.compactMap({ $0.text }).joined(separator: "\n"), !text.isEmpty {
                return text
            }
            throw GeminiError.invalidResponse
        } catch {
            throw GeminiError.network(error)
        }
    }

    // MARK: - Post-processing to enforce brevity and plain text
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


