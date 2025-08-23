import SwiftUI

struct LLMSettingsView: View {
    @StateObject private var llmManager = LLMManager.shared
    @State private var showingModelPicker = false
    @State private var availableOllamaModels: [String] = []
    @State private var isLoadingModels = false
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AI Provider")
                .font(.headline)
                .foregroundColor(themeManager.currentTheme.foregroundColor)
            
            // Provider Selection
            VStack(alignment: .leading, spacing: 12) {
                ForEach(LLMProviderType.allCases, id: \.self) { provider in
                    providerRow(provider)
                }
            }
            
            Divider()
            
            // Provider-specific settings
            if llmManager.currentProvider == .ollama {
                ollamaSettings()
            } else if llmManager.currentProvider == .gemini {
                geminiSettings()
            }
            
            Spacer()
        }
        .padding()
        .task {
            await llmManager.updateAvailableProviders()
        }
    }
    
    @ViewBuilder
    private func providerRow(_ provider: LLMProviderType) -> some View {
        HStack {
            RadioButton(
                isSelected: llmManager.currentProvider == provider,
                isEnabled: llmManager.availableProviders.contains(provider)
            ) {
                if llmManager.availableProviders.contains(provider) {
                    llmManager.setProvider(provider)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(provider.displayName)
                    .font(.system(.body, design: .default, weight: .medium))
                    .foregroundColor(themeManager.currentTheme.foregroundColor)
                
                Text(providerDescription(provider))
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.6))
            }
            
            Spacer()
            
            providerStatusIndicator(provider)
        }
        .opacity(llmManager.availableProviders.contains(provider) ? 1.0 : 0.6)
    }
    
    private func providerDescription(_ provider: LLMProviderType) -> String {
        switch provider {
        case .gemini:
            return "Google's AI • Requires API key • May have rate limits"
        case .ollama:
            return "Local AI • No API key needed • No rate limits"
        }
    }
    
    @ViewBuilder
    private func providerStatusIndicator(_ provider: LLMProviderType) -> some View {
        if llmManager.availableProviders.contains(provider) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
        } else {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.orange)
                .font(.caption)
        }
    }
    
    @ViewBuilder
    private func ollamaSettings() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ollama Settings")
                .font(.headline)
                .foregroundColor(themeManager.currentTheme.foregroundColor)
            
            if !llmManager.availableProviders.contains(.ollama) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ollama not available")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                    
                    Text("To use Ollama:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("1. Install Ollama from ollama.ai")
                        Text("2. Run 'ollama pull llama3.1:8b'")
                        Text("3. Ensure Ollama is running")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 8)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            } else {
                // Model selection for Ollama
                HStack {
                    Text("Model:")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Button(action: {
                        showingModelPicker = true
                        loadOllamaModels()
                    }) {
                        if let provider = llmManager.activeProvider as? OllamaLLMProvider {
                            Text(provider.selectedModel)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.blue)
                        } else {
                            Text("Select Model")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .buttonStyle(.plain)
                }
                
                Button("Refresh Available Providers") {
                    Task {
                        await llmManager.updateAvailableProviders()
                    }
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
        .sheet(isPresented: $showingModelPicker) {
            ollamaModelPicker()
        }
    }
    
    @ViewBuilder
    private func geminiSettings() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Gemini Settings")
                .font(.headline)
                .foregroundColor(themeManager.currentTheme.foregroundColor)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("API Key")
                    .font(.subheadline)
                    .foregroundColor(themeManager.currentTheme.foregroundColor)
                
                SecureField("Enter your Gemini API key", text: Binding(
                    get: { GeminiClient.shared.getApiKey() ?? "" },
                    set: { 
                        GeminiClient.shared.setApiKey($0)
                        Task {
                            await llmManager.updateAvailableProviders()
                        }
                    }
                ))
                .textFieldStyle(.roundedBorder)
                
                Text("Get your API key from Google AI Studio (ai.google.dev)")
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.6))
                
                if llmManager.availableProviders.contains(.gemini) {
                    Text("✓ Gemini is configured and ready")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
    }
    
    @ViewBuilder
    private func ollamaModelPicker() -> some View {
        NavigationView {
            VStack {
                if isLoadingModels {
                    ProgressView("Loading models...")
                        .padding()
                } else if availableOllamaModels.isEmpty {
                    Text("No models found. Pull models using:\nollama pull llama3.1:8b")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                } else {
                    List(availableOllamaModels, id: \.self) { model in
                        Button(action: {
                            if let provider = llmManager.activeProvider as? OllamaLLMProvider {
                                provider.selectedModel = model
                            }
                            showingModelPicker = false
                        }) {
                            HStack {
                                Text(model)
                                    .font(.system(.body, design: .monospaced))
                                
                                Spacer()
                                
                                if let provider = llmManager.activeProvider as? OllamaLLMProvider,
                                   provider.selectedModel == model {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Select Model")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingModelPicker = false
                    }
                }
            }
        }
    }
    
    private func loadOllamaModels() {
        guard let ollamaProvider = llmManager.activeProvider as? OllamaLLMProvider else { return }
        
        isLoadingModels = true
        Task {
            do {
                let models = try await ollamaProvider.getAvailableModels()
                await MainActor.run {
                    self.availableOllamaModels = models
                    self.isLoadingModels = false
                }
            } catch {
                await MainActor.run {
                    self.availableOllamaModels = []
                    self.isLoadingModels = false
                }
            }
        }
    }
}

// MARK: - Radio Button Component

struct RadioButton: View {
    let isSelected: Bool
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Circle()
                .fill(isSelected ? Color.blue : Color.clear)
                .frame(width: 16, height: 16)
                .overlay(
                    Circle()
                        .stroke(isEnabled ? Color.blue : Color.gray, lineWidth: 2)
                )
                .overlay(
                    Circle()
                        .fill(Color.white)
                        .frame(width: 6, height: 6)
                        .opacity(isSelected ? 1 : 0)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

#Preview {
    LLMSettingsView()
        .frame(width: 400, height: 500)
}
