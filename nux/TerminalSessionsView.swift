import SwiftUI

struct SessionItem: Identifiable, Equatable {
    let id: UUID
    let session: TerminalSession
    init(session: TerminalSession) {
        self.id = UUID()
        self.session = session
    }
    static func == (lhs: SessionItem, rhs: SessionItem) -> Bool { lhs.id == rhs.id }
}

struct TerminalSessionsView: View {
    @State private var sessions: [SessionItem] = []
    @State private var selectedId: UUID?
    @State private var isSummarizing = false
    @State private var summary: SessionSummary? = nil
    @State private var showSummarySheet = false
    @State private var showSettingsSheet = false
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } detail: {
            if let session = currentSession?.session {
                TerminalView(terminal: session)
            } else {
                Text("Select or create a session")
                    .foregroundColor(.secondary)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .environmentObject(themeManager)
        .onAppear { ensureOneSession() }
        .sheet(isPresented: $showSummarySheet) {
            SummarySheet(isLoading: isSummarizing, summary: summary)
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsView()
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: { showSettingsSheet = true }) { Image(systemName: "gear") }
            }
        }
    }
    
    private var currentSession: SessionItem? {
        guard let id = selectedId else { return sessions.first }
        return sessions.first(where: { $0.id == id })
    }
    
    private func ensureOneSession() {
        guard sessions.isEmpty else { return }
        newSession()
    }
    
    private func newSession() {
        withAnimation(.easeInOut(duration: 0.2)) {
            let s = TerminalSession(startDirectory: "/")
            s.startSession()
            let item = SessionItem(session: s)
            sessions.append(item)
            selectedId = item.id
        }
    }
    
    private func title(for session: TerminalSession) -> String {
        let path = session.currentDirectory
        return TerminalTab.titleFromPath(path)
    }
    
    private func close(_ id: UUID) {
        withAnimation(.easeInOut(duration: 0.2)) {
            guard let idx = sessions.firstIndex(where: { $0.id == id }) else { return }
            let wasSelected = sessions[idx].id == selectedId
            sessions.remove(at: idx)
            if sessions.isEmpty { newSession(); return }
            if wasSelected { selectedId = sessions[min(idx, sessions.count-1)].id }
        }
    }
    
    private func delete(at offsets: IndexSet) {
        offsets.forEach { idx in close(sessions[idx].id) }
    }
    
    private func closeSelected() { if let id = selectedId { close(id) } }
    
    private func summarizeSelected() { if let item = currentSession { summarize(item.session) } }
    
    private func summarize(_ session: TerminalSession) {
        // Check if there are any commands to summarize
        let hasCommands = session.outputs.contains { $0.type == .command }
        
        // Debug: Print the outputs to see what's actually there
        print("Session outputs count: \(session.outputs.count)")
        print("Output types: \(session.outputs.map { $0.type })")
        print("Has commands: \(hasCommands)")
        
        if !hasCommands {
            // Prepare empty state and then present
            isSummarizing = false
            summary = nil
            showSummarySheet = true
            return
        }
        
        // Ensure loading state is set BEFORE presenting the sheet so spinner shows immediately
        isSummarizing = true
        summary = nil
        showSummarySheet = true
        Task { @MainActor in
            do {
                let s = try await LLMManager.shared.summarizeStructured(outputs: session.outputs)
                summary = s
            } catch {
                summary = .init(
                    summary: error.localizedDescription, 
                    commands: [], 
                    errors: [], 
                    nextSteps: [],
                    keyInsights: [],
                    potentialIssues: [],
                    usefulCommands: [],
                    currentState: "",
                    recommendations: []
                )
            }
            isSummarizing = false
        }
    }
}

private extension TerminalSessionsView {
    var sidebar: some View {
        VStack(spacing: 0) {
            // Header with title and New Session button at the top
            HStack(spacing: 8) {
                Text("Sessions")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.7))
                Spacer()
                Button(action: newSession) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(themeManager.currentTheme.accentColor)
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(themeManager.currentTheme.backgroundColor.opacity(0.4))
                        )
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(themeManager.currentTheme.backgroundColor)

            List(selection: $selectedId) {
                ForEach(sessions) { item in
                    HStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "terminal")
                            Text(title(for: item.session))
                                .lineLimit(1)
                                .truncationMode(.head)
                        }
                        Spacer()
                        Button {
                            summarize(item.session)
                        } label: {
                            Image(systemName: "text.bubble")
                                .foregroundColor((selectedId == item.id) ? themeManager.currentTheme.foregroundColor : themeManager.currentTheme.accentColor)
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.borderless)
                        .id("summarize-\(themeManager.currentTheme.accentColor.description)")
                        Button {
                            close(item.id)
                        } label: {
                            Image(systemName: "xmark")
                                .foregroundColor(themeManager.currentTheme.foregroundColor)
                        }
                        .buttonStyle(.borderless)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .tag(item.id)
                    .contextMenu {
                        Button("Summarize") { summarize(item.session) }
                        Button("Close") { close(item.id) }
                    }
                }
                .onDelete(perform: delete)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(themeManager.currentTheme.backgroundColor)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider()
                .background(themeManager.currentTheme.foregroundColor.opacity(0.1))
            
            // Footer space preserved for future items
            Color.clear.frame(height: 1)
        }
        .frame(minWidth: 260, maxWidth: .infinity)
    }
}

private struct SummarySheet: View {
    @EnvironmentObject var themeManager: ThemeManager
    let isLoading: Bool
    let summary: SessionSummary?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Session Summary")
                .font(.title3).bold()
                .foregroundColor(themeManager.currentTheme.foregroundColor)
                .id("summary-title-\(themeManager.currentTheme.foregroundColor.description)")
            
            if isLoading {
                Spacer()
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .progressViewStyle(CircularProgressViewStyle(tint: themeManager.currentTheme.accentColor))
                    
                    Text("Analyzing session...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.8))
                    
                    Text("This may take a few moments")
                        .font(.system(size: 13))
                        .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.6))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                Spacer()
            } else if let s = summary {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Current State - Most important info first
                        if !s.currentState.isEmpty {
                            cardSection(title: "Current State", content: s.currentState, accentColor: themeManager.currentTheme.accentColor, icon: "location.fill")
                        }
                        
                        // Summary
                        cardSection(title: "What Happened", content: s.summary, accentColor: themeManager.currentTheme.accentColor, icon: "doc.text")
                        
                        // Key Insights - Most valuable for user
                        if !s.keyInsights.isEmpty {
                            cardSection(title: "Key Insights", items: s.keyInsights, accentColor: .orange, icon: "lightbulb.fill")
                        }
                        
                        // Next Steps - Actionable items
                        if !s.nextSteps.isEmpty {
                            cardSection(title: "Next Steps", items: s.nextSteps, accentColor: .green, icon: "arrow.right.circle.fill")
                        }
                        
                        // Potential Issues - Things to watch out for
                        if !s.potentialIssues.isEmpty {
                            cardSection(title: "Potential Issues", items: s.potentialIssues, accentColor: .red, icon: "exclamationmark.triangle.fill")
                        }
                        
                        // Errors
                        if !s.errors.isEmpty {
                            cardSection(title: "Errors", items: s.errors, accentColor: .red, icon: "xmark.circle.fill")
                        }
                        
                        // Recommendations
                        if !s.recommendations.isEmpty {
                            cardSection(title: "Recommendations", items: s.recommendations, accentColor: .blue, icon: "star.fill")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 20)
                }
            } else {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "terminal")
                        .font(.system(size: 48))
                        .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.4))
                    
                    Text("Summary Not Available")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(themeManager.currentTheme.foregroundColor)
                    
                    Text("Start with some commands to generate a summary")
                        .font(.system(size: 14))
                        .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.7))
                        .multilineTextAlignment(.center)
                    
                    VStack(spacing: 8) {
                        Text("Try commands like:")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.6))
                        
                        VStack(spacing: 4) {
                            Text("ls -la")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(themeManager.currentTheme.accentColor)
                            Text("pwd")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(themeManager.currentTheme.accentColor)
                            Text("git status")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(themeManager.currentTheme.accentColor)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                Spacer()
            }
            HStack { Spacer(); Button("Close") { dismiss() } }
        }
        .padding(20)
        .frame(minWidth: 560, maxWidth: 800, minHeight: 500, maxHeight: 700)
        .background(themeManager.currentTheme.backgroundColor)
    }
    
    @Environment(\.dismiss) private var dismiss
    
    private func cardSection(title: String, content: String, accentColor: Color, icon: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundColor(accentColor)
                        .font(.system(size: 14))
                }
                Text(title)
                    .font(.headline)
                    .foregroundColor(accentColor)
            }
            
            Text(content)
                .font(.system(size: 14))
                .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(themeManager.currentTheme.backgroundColor.opacity(0.3))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(accentColor.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(12)
    }
    
    private func cardSection(title: String, items: [String], accentColor: Color, icon: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundColor(accentColor)
                        .font(.system(size: 14))
                }
                Text(title)
                    .font(.headline)
                    .foregroundColor(accentColor)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items.indices, id: \.self) { i in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(accentColor)
                            .font(.system(size: 12, weight: .bold))
                        Text(items[i])
                            .font(.system(size: 14))
                            .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(themeManager.currentTheme.backgroundColor.opacity(0.3))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(accentColor.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

#Preview {
    TerminalSessionsView()
}


