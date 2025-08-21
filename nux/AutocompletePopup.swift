import SwiftUI

struct AutocompletePopup: View {
    let suggestions: [String]
    let selectedIndex: Int
    let visibleStartIndex: Int
    let currentInput: String
    let onItemClick: (Int) -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    private let maxVisibleItems = AutocompleteConstants.maxVisibleItems
    private let itemHeight: CGFloat = AutocompleteConstants.itemHeight
    
    var body: some View {
        if !suggestions.isEmpty {
            HStack(alignment: .top, spacing: AutocompleteConstants.popupItemSpacing) {
                // Main popup list with limited visible items
                ScrollView {
                    ScrollViewReader { proxy in
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                                Button(action: {
                                    onItemClick(index)
                                }) {
                                    HStack(spacing: AutocompleteConstants.iconSpacing) {
                                        // Selection indicator
                                        Circle()
                                            .fill(index == selectedIndex ? themeManager.currentTheme.accentColor : Color.clear)
                                            .frame(width: AutocompleteConstants.selectionIndicatorSize, height: AutocompleteConstants.selectionIndicatorSize)
                                        
                                        // Command icon
                                        Image(systemName: getIconForSuggestion(suggestion))
                                            .foregroundColor(index == selectedIndex ? themeManager.currentTheme.accentColor : themeManager.currentTheme.foregroundColor.opacity(AutocompleteConstants.iconInactiveOpacity))
                                            .font(.system(size: AutocompleteConstants.iconSize))
                                            .frame(width: AutocompleteConstants.iconFrameWidth)
                                        
                                        // Suggestion text (only the word being completed)
                                        Text(getCompletionWord(from: suggestion))
                                            .font(.system(size: AutocompleteConstants.completionFontSize, design: .monospaced))
                                            .foregroundColor(index == selectedIndex ? themeManager.currentTheme.foregroundColor : themeManager.currentTheme.foregroundColor.opacity(AutocompleteConstants.textInactiveOpacity))
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                            .frame(maxWidth: AutocompleteConstants.maxCompletionWidth, alignment: .leading)
                                        
                                        Spacer()
                                        
                                        // Type indicator
                                        Text(getTypeForSuggestion(suggestion))
                                            .font(.system(size: AutocompleteConstants.typeBadgeFontSize, weight: .medium))
                                            .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(AutocompleteConstants.typeBadgeTextOpacity))
                                            .padding(.horizontal, AutocompleteConstants.typeBadgeHorizontalPadding)
                                            .padding(.vertical, AutocompleteConstants.typeBadgeVerticalPadding)
                                            .background(themeManager.currentTheme.foregroundColor.opacity(AutocompleteConstants.typeBadgeBackgroundOpacity))
                                            .cornerRadius(AutocompleteConstants.typeBadgeCornerRadius)
                                    }
                                    .frame(height: itemHeight)
                                    .padding(.horizontal, AutocompleteConstants.itemHorizontalPadding)
                                    .background(index == selectedIndex ? themeManager.currentTheme.accentColor.opacity(AutocompleteConstants.selectionBackgroundOpacity) : Color.clear)
                                    .cornerRadius(AutocompleteConstants.itemCornerRadius)
                                }
                                .buttonStyle(.plain)
                                .id(index) // For scroll-to functionality
                            }
                        }
                        .onChange(of: selectedIndex) {
                            // Auto-scroll to keep selected item visible
                            withAnimation(.easeOut(duration: AutocompleteConstants.animationDuration)) {
                                proxy.scrollTo(selectedIndex, anchor: .center)
                            }
                        }
                    }
                }
                .frame(height: CGFloat(min(maxVisibleItems, suggestions.count)) * itemHeight) // Fixed height for max 6 items
                .clipped() // Ensure content doesn't overflow
                .scrollIndicators(.hidden) // Hide default scroll indicators for cleaner look
                .padding(.vertical, AutocompleteConstants.popupVerticalPadding)
                .background(themeManager.currentTheme.backgroundColor.opacity(AutocompleteConstants.backgroundOpacity))
                .cornerRadius(AutocompleteConstants.popupCornerRadius)

                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(themeManager.currentTheme.foregroundColor.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: 4) // Stronger shadow for popup effect
                .padding(.bottom, 8) // Extra padding to ensure shadow doesn't get clipped
                
                // Details box for selected item - positioned at center since we scroll to center
                if selectedIndex < suggestions.count {
                    VStack {
                        Spacer()
                        
                        // Details box
                        HStack {
                            Text(suggestions[selectedIndex])
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(themeManager.currentTheme.foregroundColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(themeManager.currentTheme.backgroundColor.opacity(0.95))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(themeManager.currentTheme.accentColor.opacity(0.5), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.3), radius: 6, x: 2, y: 2)
                            
                            Spacer()
                        }
                        
                        Spacer()
                    }
                    .frame(height: CGFloat(min(maxVisibleItems, suggestions.count)) * itemHeight + 8) // Match popup height
                }
            }
        }
    }
    
    private func getCompletionWord(from suggestion: String) -> String {
        let inputComponents = currentInput.components(separatedBy: .whitespaces)
        let suggestionComponents = suggestion.components(separatedBy: .whitespaces)
        
        // If we're completing a command (single word input like "gi" -> "git")
        if inputComponents.count == 1 {
            return suggestionComponents.first ?? suggestion
        }
        
        // For multi-word commands (like "ls" + file/directory completion)
        // We want to show the file/directory name, not the command
        if suggestionComponents.count > 1 {
            // Skip the command part and get the file/directory being completed
            let argumentParts = Array(suggestionComponents.dropFirst()) // Remove "ls" part
            let argumentString = argumentParts.joined(separator: " ")
            
            // If it's a file path, return just the filename/dirname
            if argumentString.contains("/") {
                return URL(fileURLWithPath: argumentString).lastPathComponent
            }
            
            return argumentString
        }
        
        // Single component - check if it's a file path
        if suggestion.contains("/") {
            return URL(fileURLWithPath: suggestion).lastPathComponent
        }
        
        return suggestion
    }
    
    private func getIconForSuggestion(_ suggestion: String) -> String {
        let components = suggestion.components(separatedBy: .whitespaces)
        guard let command = components.first else { return "terminal" }
        
        switch command.lowercased() {
        case "ls", "ll", "la":
            return "list.bullet"
        case "cd":
            return "folder"
        case "git":
            return "arrow.triangle.branch"
        case "npm", "yarn":
            return "cube.box"
        case "docker":
            return "shippingbox"
        case "python", "python3":
            return "snake.fill"
        case "node":
            return "leaf"
        case "swift", "swiftc":
            return "swift"
        case "mkdir":
            return "folder.badge.plus"
        case "rm", "rmdir":
            return "trash"
        case "cp", "mv":
            return "doc.on.doc"
        case "cat", "less", "more":
            return "doc.text"
        case "grep", "find":
            return "magnifyingglass"
        case "ps", "top", "kill":
            return "cpu"
        case "ssh":
            return "network"
        case "brew":
            return "mug"
        default:
            // Check if it's a file/directory
            if suggestion.hasSuffix("/") {
                return "folder.fill"
            } else if suggestion.contains(".") {
                return "doc.fill"
            }
            return "terminal"
        }
    }
    
    private func getTypeForSuggestion(_ suggestion: String) -> String {
        let components = suggestion.components(separatedBy: .whitespaces)
        
        if components.count == 1 {
            return "cmd"
        } else if suggestion.hasSuffix("/") {
            return "dir"
        } else if suggestion.contains(".") {
            return "file"
        } else {
            return "arg"
        }
    }
}

#Preview {
    @StateObject var themeManager = ThemeManager()
    
    return AutocompletePopup(
        suggestions: ["ls", "cd ~/", "git status", "npm install", "python3 main.py", "docker run"],
        selectedIndex: 2,
        visibleStartIndex: 0,
        currentInput: "git st",
        onItemClick: { _ in }
    )
    .environmentObject(themeManager)
    .padding()
    .frame(width: 300)
}
