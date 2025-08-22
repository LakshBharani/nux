import SwiftUI

struct TerminalTab: Identifiable, Equatable {
    let id: UUID
    let session: TerminalSession
    var title: String
    
    init(session: TerminalSession, title: String? = nil) {
        self.id = UUID()
        self.session = session
        // Avoid cross-actor access to session properties here; will be shown live by TabLabelView
        self.title = title ?? "New Terminal"
    }
    
    static func == (lhs: TerminalTab, rhs: TerminalTab) -> Bool {
        lhs.id == rhs.id
    }

    // Deprecated: use TabLabelView for live titles
    @available(*, deprecated)
    static func deriveTitle(from session: TerminalSession) -> String { titleFromPath("") }
    
    static func titleFromPath(_ path: String) -> String {
        guard !path.isEmpty else { return "New Terminal" }
        let components = URL(fileURLWithPath: path).pathComponents.filter { $0 != "/" && !$0.isEmpty }
        if components.isEmpty { return "New Terminal" }
        let lastTwo = components.suffix(2)
        return lastTwo.joined(separator: "/")
    }
}

struct TerminalTabsView: View {
    @State private var tabs: [TerminalTab] = []
    @State private var selectedTabId: UUID?
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var renamingTabId: UUID? = nil
    @State private var renamingText: String = ""
    @FocusState private var isRenamingFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
                .background(themeManager.currentTheme.foregroundColor.opacity(0.08))
            if let selectedTab = currentTab {
                TerminalView(terminal: selectedTab.session)
            } else {
                // Initialize first tab lazily
                Color.clear
                    .onAppear { ensureAtLeastOneTab() }
            }
        }
        .background(themeManager.currentTheme.backgroundColor)
        .onAppear { ensureAtLeastOneTab() }
        .environmentObject(themeManager)
        .background(
            // Hidden keyboard shortcuts (do not intercept mouse/touch events)
            Group {
                Button("") { addTab() }
                    .keyboardShortcut("t", modifiers: .command)
                    .hidden()
                Button("") { closeCurrentTab() }
                    .keyboardShortcut("w", modifiers: .command)
                    .hidden()
            }
            .allowsHitTesting(false)
        )
    }
    
    private var tabBar: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(tabs) { tab in
                        tabItem(tab)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            Button(action: { addTab() }) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.9))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(themeManager.currentTheme.backgroundColor.opacity(0.6))
                    )
            }
            .buttonStyle(.plain)
            .keyboardShortcut("t", modifiers: .command)
            .padding(.trailing, 8)
            .contentShape(Rectangle())
            .zIndex(10)
        }
        .background(themeManager.currentTheme.backgroundColor)
        .zIndex(10)
    }
    
    private func tabItem(_ tab: TerminalTab) -> some View {
        let isSelected = tab.id == selectedTabId
        return HStack(spacing: 8) {
            Group {
                if renamingTabId == tab.id {
                    TextField("Tab name", text: Binding(get: { renamingText }, set: { renamingText = $0 }))
                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular, design: .default))
                        .textFieldStyle(.plain)
                        .foregroundColor(themeManager.currentTheme.foregroundColor)
                        .frame(minWidth: 80)
                        .focused($isRenamingFocused)
                        .onAppear {
                            renamingText = tab.title
                            DispatchQueue.main.async { isRenamingFocused = true }
                        }
                        .onSubmit { commitRename(tabId: tab.id) }
                        .onExitCommand { commitRename(tabId: tab.id) }
                } else {
                    Button(action: { selectedTabId = tab.id }) {
                        TabLabelView(session: tab.session, isSelected: isSelected, titleOverride: tab.title)
                            .padding(.vertical, 0)
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture(count: 2).onEnded { startRename(tab: tab) })
                }
            }
            Button(action: { closeTab(tab.id) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.6))
                    .padding(2)
            }
            .buttonStyle(.borderless)
            .zIndex(11)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .contentShape(Rectangle())
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? themeManager.currentTheme.backgroundColor.opacity(0.6) : themeManager.currentTheme.backgroundColor.opacity(0.3))
                RoundedRectangle(cornerRadius: 8)
                    .stroke(themeManager.currentTheme.foregroundColor.opacity(isSelected ? 0.18 : 0.08))
            }
        )
        .overlay(
            Group {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(themeManager.currentTheme.accentColor.opacity(0.35), lineWidth: 1)
                }
            }
        )
        .contextMenu {
            Button("New Tab", action: addTab)
            Button("Close Tab") { closeTab(tab.id) }
        }
    }
    
    private var currentTab: TerminalTab? {
        guard let selected = selectedTabId else { return nil }
        return tabs.first(where: { $0.id == selected })
    }
    
    private func ensureAtLeastOneTab() {
        guard tabs.isEmpty else { return }
        addTab()
    }
    
    private func addTab() {
        let session = TerminalSession(startDirectory: "/")
        session.startSession()
        let tab = TerminalTab(session: session, title: "New Terminal")
        tabs.append(tab)
        selectedTabId = tab.id
    }
    
    private func closeTab(_ id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        let isClosingSelected = tabs[index].id == selectedTabId
        tabs.remove(at: index)
        if renamingTabId == id { renamingTabId = nil }
        if tabs.isEmpty {
            addTab()
            return
        }
        if isClosingSelected {
            let newIndex = min(index, tabs.count - 1)
            selectedTabId = tabs[newIndex].id
        }
    }
    
    private func closeCurrentTab() {
        if let id = selectedTabId {
            closeTab(id)
        }
    }
    
    private func displayTitle(for tab: TerminalTab) -> String {
        TerminalTab.deriveTitle(from: tab.session)
    }

    private func startRename(tab: TerminalTab) {
        renamingTabId = tab.id
        renamingText = tab.title
    }
    
    private func commitRename(tabId: UUID) {
        guard let idx = tabs.firstIndex(where: { $0.id == tabId }) else { return }
        tabs[idx].title = renamingText.trimmingCharacters(in: .whitespacesAndNewlines)
        renamingTabId = nil
    }
}

@MainActor
private struct TabLabelView: View {
    @ObservedObject var session: TerminalSession
    @EnvironmentObject var themeManager: ThemeManager
    let isSelected: Bool
    let titleOverride: String?
    
    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: isSelected ? .semibold : .regular, design: .default))
            .foregroundColor(
                isSelected ? themeManager.currentTheme.foregroundColor : themeManager.currentTheme.foregroundColor.opacity(0.7)
            )
            .lineLimit(1)
            .truncationMode(.head)
            .frame(minWidth: 60)
    }
    
    private var title: String {
        if let t = titleOverride, !t.isEmpty { return t }
        return TerminalTab.titleFromPath(session.currentDirectory)
    }
}

#Preview {
    TerminalTabsView()
        .frame(width: 900, height: 600)
}


