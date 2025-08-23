import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    @State private var selectedTheme = "nux Dark"
    
    private let themes = [
        ("nux Dark", TerminalTheme.nuxDark),
        ("Cyberpunk", TerminalTheme.cyberpunk),
        ("Dracula", TerminalTheme.dracula),
        ("Nord", TerminalTheme.nord),
        ("Solarized", TerminalTheme.solarized),
        ("Tokyo Night", TerminalTheme.tokyoNight),
        ("Gruvbox", TerminalTheme.gruvbox),
        ("Classic", TerminalTheme.classic)
    ]
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                groupBox("Appearance") {
                    Picker("Theme", selection: $selectedTheme) {
                        ForEach(themes, id: \.0) { theme in
                            Text(theme.0)
                                .foregroundColor(themeManager.currentTheme.foregroundColor)
                                .tag(theme.0)
                        }
                    }
                    .onChange(of: selectedTheme) {
                        // Apply and persist theme by name
                        themeManager.setThemeByName(selectedTheme)
                    }
                }
                
                HStack(spacing: 24) {
                    groupBox("Terminal") {
                        labeledRow("Font Size", value: "14pt")
                        labeledRow("Font Family", value: "SF Mono")
                    }
                    groupBox("About") {
                        labeledRow("Version", value: "1.0.0")
                        labeledRow("Build", value: "001")
                    }
                }
                
                groupBox("AI") {
                    LLMSettingsView()
                }
                Spacer(minLength: 0)
            }
            .padding(24)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        // Save any pending changes
                        if let theme = themes.first(where: { $0.0 == selectedTheme })?.1 {
                            themeManager.setTheme(theme)
                        }
                        dismiss()
                    }
                }
            }
        }
        .background(themeManager.currentTheme.backgroundColor)
        .frame(minWidth: 520, idealWidth: 640, maxWidth: 800, minHeight: 480, idealHeight: 560, maxHeight: 900)
        .onAppear {
            // Load persisted selection
            selectedTheme = themeManager.getSavedThemeName()
        }
    }
}

private extension SettingsView {
    @ViewBuilder
    func labeledRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(themeManager.currentTheme.foregroundColor)
            Spacer()
            Text(value)
                .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.6))
        }
    }
    
    @ViewBuilder
    func groupBox(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(themeManager.currentTheme.foregroundColor)
            content()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(themeManager.currentTheme.backgroundColor.opacity(0.1))
        )
    }
}
