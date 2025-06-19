//
//  nuxApp.swift
//  nux
//
//  Created by Laksh Bharani on 6/18/25.
//

import SwiftUI

@main
struct nuxApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandMenu("AI Assistant") {
                Button("Toggle AI Assist Mode") {
                    NotificationCenter.default.post(name: .toggleAIAssist, object: nil)
                }
                .keyboardShortcut("k", modifiers: .command)
            }
        }
        .windowResizability(.contentSize)
    }
}

