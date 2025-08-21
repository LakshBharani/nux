import SwiftUI

struct CommandSuggestions: View {
    @EnvironmentObject var themeManager: ThemeManager
    let suggestions: [String]
    let onSelect: (String) -> Void
    
    var body: some View {
        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(suggestions.prefix(5), id: \.self) { suggestion in
                    Button(action: {
                        onSelect(suggestion)
                    }) {
                        HStack {
                            Image(systemName: "terminal")
                                .foregroundColor(themeManager.currentTheme.accentColor)
                                .font(.system(size: 12))
                            
                            Text(suggestion)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(themeManager.currentTheme.foregroundColor)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(themeManager.currentTheme.backgroundColor.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .onHover { isHovered in
                        // Could add hover effects here
                    }
                }
            }
            .background(themeManager.currentTheme.backgroundColor.opacity(0.95))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(themeManager.currentTheme.foregroundColor.opacity(0.2), lineWidth: 1)
            )
            .shadow(radius: 10)
        }
    }
}

class CommandHistory: ObservableObject {
    @Published var history: [String] = []
    private var currentIndex = -1
    
    func addCommand(_ command: String) {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && (history.isEmpty || history.last != trimmed) {
            history.append(trimmed)
        }
        currentIndex = history.count
    }
    
    func previousCommand() -> String? {
        guard !history.isEmpty && currentIndex > 0 else { return nil }
        currentIndex -= 1
        return history[currentIndex]
    }
    
    func nextCommand() -> String? {
        guard !history.isEmpty && currentIndex < history.count - 1 else {
            currentIndex = history.count
            return ""
        }
        currentIndex += 1
        return history[currentIndex]
    }
    
    func getSuggestions(for input: String) -> [String] {
        guard !input.isEmpty else { return [] }
        
        let commonCommands = [
            "ls", "cd", "pwd", "mkdir", "rmdir", "rm", "cp", "mv", "cat", "grep",
            "find", "which", "chmod", "chown", "ps", "top", "kill", "killall",
            "git status", "git add", "git commit", "git push", "git pull",
            "npm install", "npm start", "npm run", "yarn install", "yarn start",
            "python", "node", "swift", "xcodebuild", "brew install", "brew update"
        ]
        
        let allCommands = Set(history + commonCommands)
        
        return Array(allCommands)
            .filter { $0.lowercased().hasPrefix(input.lowercased()) }
            .sorted()
    }
}
