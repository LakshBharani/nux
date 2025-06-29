//
//  nuxApp.swift
//  nux
//
//  Created by Laksh Bharani on 6/18/25.
//

import SwiftUI

@main
struct nuxApp: App {
    @State private var selectedModel: AIModel = .none

    
    var body: some Scene {
        WindowGroup {
            ContentView(selectedModel: $selectedModel)
        }
        .commands {
            CommandMenu("AI Assistant") {
                Button("Toggle AI Assist Mode") {
                    NotificationCenter.default.post(name:   .toggleAIAssist, object: nil)
                }
                .keyboardShortcut("k", modifiers: .command)
            }
            
            CommandMenu("AI Models") {
                Picker("Model", selection: $selectedModel) {
                    Text("None").tag(AIModel.none)
                    Text("OpenAI").tag(AIModel.openai)
                    Text("Gemini").tag(AIModel.gemini)
                }
                .pickerStyle(.inline)
            }

        }
        .windowResizability(.contentSize)
    }
}

