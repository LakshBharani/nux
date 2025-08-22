## nux

nux is a native macOS terminal built with SwiftUI. It focuses on a calm, fast experience with bottom‑aligned output (like a messages app), focused autocomplete, renameable tabs/sessions, and concise AI session summaries. The plan is to ship a polished, privacy‑respecting build to the Mac App Store.

### Status

- Actively under development (alpha).
- Planned for Mac App Store distribution once the feature set and polish are complete.

### What makes nux different

- **Readable flow**: Output grows from the bottom; each command shows a divider, run time, and working directory (metadata—never mixed into output).
- **Practical autocomplete**: Tab to open a compact popup; arrow keys to navigate; Enter/Tab to accept; ghost‑text preview for speed.
- **Sessions that make sense**: Tabs on top, session list in the sidebar, double‑click to rename.
- **Concise AI summaries**: Cards for What Happened, Key Insights, Next Steps, Issues, Errors, and Recommendations—short and scannable.
- **Themes that stick**: Modern themes (nux Dark, Classic, Cyberpunk, Dracula, Nord, Solarized, Tokyo Night, Gruvbox) persisted across launches.

### How to use

1. Build and run from Xcode (Development steps below).
2. Type in the input at the bottom to run commands.
3. Press **Tab** for autocomplete; use ↑/↓ to move; Enter/Tab to accept.
4. Click the chat bubble in the sidebar to **Summarize** a session (optional Gemini key).
5. Open **Settings** to choose a theme and add a Gemini API key.

### Development (local build)

Requirements: macOS 14+ (Sonoma), Xcode 15+

1. Clone and open:

```bash
git clone https://github.com/<your-org-or-user>/nux.git
cd nux
open nux.xcodeproj
```

2. Select the `nux` scheme → Run.

#### Configure Gemini (optional, for summaries)

1. Create an API key in Google AI Studio.
2. In nux, open `Settings` → paste your key into “Gemini API Key”.
3. Stored in UserDefaults; used only when you request a summary.

### Current progress

- Bottom‑aligned output with command metadata (directory + execution time).
- Autocomplete popup with ghost text and full keyboard navigation.
- Resizable sidebar; rows and footer fill available width.
- Multi‑tab (renameable), session list, close/restore, keyboard shortcuts.
- AI summary sheet with compact cards and strict brevity rules.
- Theme system with persistence; multiple modern themes.
- Shell environment caching for faster commands while keeping user PATH.

### Roadmap

Near‑term

- Command palette + fuzzy opener.
- Rich inline previews (text/images) and quick‑look actions.
- Persist window/session state across launches.

GenAI and Agentic AI

- Provider abstraction for local and cloud models.
- Agentic workflows: propose next actions and (optionally) execute with user confirmation.
- Tool use: file edits, directory ops, git operations, process control—scoped and auditable.
- Session memory: persistent context + semantic search over transcripts.
- Inline explanations, fixes, and command rewrite suggestions.

### Keyboard shortcuts

- New Tab: `⌘T` · Close Tab: `⌘W` · Settings: `⌘,` · Autocomplete: `Tab`

### Theming

- Pick a theme in **Settings**; it persists across launches.

### Project structure

```
nux/
  nux/                   # App sources
    TerminalTabsView.swift      # Tabs UI + renameable titles
    TerminalSessionsView.swift  # Sidebar, sessions, summaries
    TerminalView.swift          # Output list, input bar
    ControlBarSimplified.swift  # Input, autocomplete, directory UI
    AutocompletePopup.swift     # Suggestion popup
    ThemeManager.swift          # Themes + persistence
    SettingsView.swift          # Theme + Gemini settings
    GeminiClient.swift          # Summarization client + post‑processing
    TerminalSession.swift       # Command execution, timing, directory
```

### Troubleshooting

- "Command not found" for tools like `go` or `brew`:
  - nux loads your shell environment once per session and caches it. Open a new tab after changing your shell config.
- Summary shows “Not Available” on first open:
  - Make sure you’ve run at least one command in the session; summaries need a transcript.

### Contributing

Issues and PRs are welcome. Please keep the UI simple, fast, and consistent with the existing SwiftUI code style.

### License

Add your license of choice (e.g., MIT) in a `LICENSE` file.
