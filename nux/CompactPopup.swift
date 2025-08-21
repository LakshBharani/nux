import SwiftUI

struct PopupItem {
    let id: String
    let text: String
    let icon: String
    let type: PopupItemType
    let action: () -> Void
    
    enum PopupItemType {
        case command
        case file
        case directory
        case parent
    }
}

struct CompactPopup: View {
    let items: [PopupItem]
    let selectedIndex: Int
    let onItemSelect: (Int) -> Void
    let onDismiss: () -> Void
    
    @EnvironmentObject var themeManager: ThemeManager
    @State private var hoveredIndex: Int? = nil
    
    private let maxVisibleItems = AutocompleteConstants.maxVisibleItems
    private let itemHeight: CGFloat = AutocompleteConstants.itemHeight
    
    var body: some View {
        // Items list
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        itemRow(item: item, index: index, isSelected: index == selectedIndex)
                            .id(index)
                    }
                }
            }
            .frame(height: CGFloat(min(maxVisibleItems, items.count)) * itemHeight)
            .scrollIndicators(.hidden)
            .onChange(of: selectedIndex) {
                withAnimation(.easeOut(duration: AutocompleteConstants.animationDuration)) {
                    proxy.scrollTo(selectedIndex, anchor: .center)
                }
            }
        }
        .padding(.vertical, AutocompleteConstants.popupVerticalPadding)
        .background(themeManager.currentTheme.backgroundColor.opacity(AutocompleteConstants.backgroundOpacity))
        .cornerRadius(AutocompleteConstants.popupCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: AutocompleteConstants.popupCornerRadius)
                .stroke(themeManager.currentTheme.foregroundColor.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: 4)
        .fixedSize(horizontal: true, vertical: false)
        .onKeyPress(.upArrow) {
            if !items.isEmpty {
                let newIndex = selectedIndex > 0 ? selectedIndex - 1 : items.count - 1
                onItemSelect(newIndex)
            }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if !items.isEmpty {
                let newIndex = selectedIndex < items.count - 1 ? selectedIndex + 1 : 0
                onItemSelect(newIndex)
            }
            return .handled
        }
        .onKeyPress(.tab) {
            if !items.isEmpty {
                let newIndex = selectedIndex < items.count - 1 ? selectedIndex + 1 : 0
                onItemSelect(newIndex)
            }
            return .handled
        }
        .onKeyPress(.return) {
            if selectedIndex < items.count {
                items[selectedIndex].action()
            }
            return .handled
        }
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
        }
    }
    

    
    private func itemRow(item: PopupItem, index: Int, isSelected: Bool) -> some View {
        Button(action: {
            item.action()
        }) {
            HStack(spacing: AutocompleteConstants.iconSpacing) {
                // Selection indicator
                Circle()
                    .fill(isSelected ? themeManager.currentTheme.accentColor : Color.clear)
                    .frame(width: AutocompleteConstants.selectionIndicatorSize, height: AutocompleteConstants.selectionIndicatorSize)
                
                // Item icon
                Image(systemName: item.icon)
                    .foregroundColor(getIconColor(for: item.type, isSelected: isSelected))
                    .font(.system(size: AutocompleteConstants.iconSize))
                    .frame(width: AutocompleteConstants.iconFrameWidth)
                
                // Item text
                Text(item.text)
                    .font(.system(size: AutocompleteConstants.completionFontSize, design: .monospaced))
                    .foregroundColor(getTextColor(for: item.type, isSelected: isSelected))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: AutocompleteConstants.maxCompletionWidth, alignment: .leading)
                
                Spacer()
                
                // Type badge
                Text(getTypeBadge(for: item.type))
                    .font(.system(size: AutocompleteConstants.typeBadgeFontSize, weight: .medium))
                    .foregroundColor(getBadgeTextColor(for: item.type))
                    .padding(.horizontal, AutocompleteConstants.typeBadgeHorizontalPadding)
                    .padding(.vertical, AutocompleteConstants.typeBadgeVerticalPadding)
                    .background(getBadgeBackgroundColor(for: item.type))
                    .cornerRadius(AutocompleteConstants.typeBadgeCornerRadius)
            }
            .frame(height: itemHeight)
            .padding(.horizontal, AutocompleteConstants.itemHorizontalPadding)
            .background(isSelected ? themeManager.currentTheme.accentColor.opacity(AutocompleteConstants.selectionBackgroundOpacity) : Color.clear)
            .cornerRadius(AutocompleteConstants.itemCornerRadius)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered in
            hoveredIndex = isHovered ? index : nil
        }
    }
    
    // MARK: - Styling Helpers
    
    private func getIconColor(for type: PopupItem.PopupItemType, isSelected: Bool) -> Color {
        if isSelected {
            return themeManager.currentTheme.accentColor
        }
        
        switch type {
        case .command:
            return themeManager.currentTheme.foregroundColor.opacity(0.7)
        case .directory:
            return themeManager.currentTheme.accentColor
        case .file:
            return themeManager.currentTheme.foregroundColor.opacity(0.6)
        case .parent:
            return themeManager.currentTheme.foregroundColor.opacity(0.5)
        }
    }
    
    private func getTextColor(for type: PopupItem.PopupItemType, isSelected: Bool) -> Color {
        if isSelected {
            return themeManager.currentTheme.foregroundColor
        }
        
        switch type {
        case .parent:
            return themeManager.currentTheme.foregroundColor.opacity(0.5)
        default:
            return themeManager.currentTheme.foregroundColor.opacity(0.8)
        }
    }
    
    private func getTypeBadge(for type: PopupItem.PopupItemType) -> String {
        switch type {
        case .command:
            return "cmd"
        case .directory:
            return "dir"
        case .file:
            return "file"
        case .parent:
            return "parent"
        }
    }
    
    private func getBadgeTextColor(for type: PopupItem.PopupItemType) -> Color {
        switch type {
        case .directory:
            return themeManager.currentTheme.accentColor.opacity(0.7)
        case .parent:
            return themeManager.currentTheme.foregroundColor.opacity(0.3)
        default:
            return themeManager.currentTheme.foregroundColor.opacity(0.4)
        }
    }
    
    private func getBadgeBackgroundColor(for type: PopupItem.PopupItemType) -> Color {
        switch type {
        case .directory:
            return themeManager.currentTheme.accentColor.opacity(0.1)
        case .parent:
            return themeManager.currentTheme.foregroundColor.opacity(0.05)
        default:
            return themeManager.currentTheme.foregroundColor.opacity(0.05)
        }
    }
}

#Preview {
    @Previewable @StateObject var themeManager = ThemeManager()
    
    let sampleItems = [
        PopupItem(id: "1", text: ".. (Parent Directory)", icon: "arrow.up.left", type: .parent, action: {}),
        PopupItem(id: "2", text: "Documents", icon: "folder.fill", type: .directory, action: {}),
        PopupItem(id: "3", text: "Downloads", icon: "folder.fill", type: .directory, action: {}),
        PopupItem(id: "4", text: "file.txt", icon: "doc.fill", type: .file, action: {}),
        PopupItem(id: "5", text: "git status", icon: "terminal", type: .command, action: {}),
    ]
    
    return CompactPopup(
        items: sampleItems,
        selectedIndex: 1,
        onItemSelect: { _ in },
        onDismiss: { }
    )
    .environmentObject(themeManager)
    .padding()
    .frame(width: 300)
}
