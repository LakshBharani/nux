import SwiftUI

@main
struct nuxApp: App {
    @StateObject private var themeManager = ThemeManager()
    var body: some Scene {
        WindowGroup {
            TerminalSessionsView()
                .frame(minWidth: 800, minHeight: 600)
                .environmentObject(themeManager)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
    }
}
