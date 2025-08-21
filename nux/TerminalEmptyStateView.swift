import SwiftUI

struct TerminalEmptyStateView: View {
    @EnvironmentObject var themeManager: ThemeManager
    var onSelectSuggestion: ((String) -> Void)? = nil
    private let maxContentWidth: CGFloat = 820
    
    private struct Suggestion: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let command: String
    }
    
    private var suggestions: [Suggestion] {
        [
            Suggestion(title: "Install a package", subtitle: "Homebrew package manager", command: "brew install <package>"),
            Suggestion(title: "Open project in editor", subtitle: "From current directory", command: "code ."),
            Suggestion(title: "Check system info", subtitle: "Kernel and architecture", command: "uname -a"),
            Suggestion(title: "List files", subtitle: "Long format, human readable", command: "ls -la"),
            Suggestion(title: "Get help", subtitle: "Built-in commands", command: "help")
        ]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack(spacing: 10) {
                Text("$")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(themeManager.currentTheme.accentColor)
                Text("nux.")
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundColor(themeManager.currentTheme.foregroundColor)
            }
            
            Text("Try one of these commands")
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.7))
                .padding(.bottom, 4)
            
            VStack(spacing: 8) {
                ForEach(suggestions) { item in
                    SuggestionRow(
                        title: item.title,
                        subtitle: item.subtitle,
                        command: item.command,
                        onTap: { onSelectSuggestion?(item.command) }
                    )
                    .environmentObject(themeManager)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .frame(maxWidth: maxContentWidth, alignment: .center)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

private struct SuggestionRow: View {
    let title: String
    let subtitle: String
    let command: String
    let onTap: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isHovering: Bool = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Prompt chevron
                Text(">")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(themeManager.currentTheme.accentColor)
                    .frame(width: 14)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(themeManager.currentTheme.foregroundColor)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundColor(themeManager.currentTheme.commentColor)
                }
                
                Spacer()
                
                Text(command)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(themeManager.currentTheme.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(themeManager.currentTheme.foregroundColor.opacity(0.07))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(themeManager.currentTheme.foregroundColor.opacity(0.1), lineWidth: 1)
                    )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isHovering ? themeManager.currentTheme.foregroundColor.opacity(0.06) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(themeManager.currentTheme.foregroundColor.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hover in
            isHovering = hover
        }
    }
}

#Preview {
    TerminalEmptyStateView()
        .environmentObject(ThemeManager())
        .frame(width: 1000, height: 500)
        .background(ThemeManager().currentTheme.backgroundColor)
}


