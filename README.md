# nux - AI-Powered macOS Terminal

**nux** is a native macOS terminal built with SwiftUI that brings AI intelligence to your command line. It transforms the traditional terminal into an intelligent, context-aware development environment.

## What is nux?

nux reimagines the terminal experience by treating the command line as a conversational interface. It combines the power of traditional Unix tools with modern AI capabilities, creating a development environment that understands your workflow and provides proactive assistance.

## Key Features

### 🤖 AI-Powered Intelligence

- **Session Summaries**: Get intelligent summaries of your terminal sessions with actionable insights
- **Context-Aware Assistant**: Ask questions about your terminal session and get contextual answers
- **Command Explanations**: Understand complex commands with AI-powered explanations

### 🎨 Modern Interface

- **Chat-Style Output**: Bottom-aligned output flow that feels natural to read
- **Rich Metadata**: Command execution time, directory, and exit status visualization
- **Beautiful Themes**: 8 modern themes including Dark, Cyberpunk, Dracula, Nord, and more

### ⚡ Enhanced Productivity

- **Smart Autocomplete**: Intelligent command suggestions with ghost text preview
- **Multi-tab Support**: Organize work with renameable tabs and session management
- **Sharable Snippets**: Share terminal snippets to keep your team up to date
- **Session Persistence**: All terminal state preserved between launches

### 🔧 Technical Excellence

- **Native Performance**: Built entirely with SwiftUI for smooth animations
- **Multiple AI Providers**: Support for Google Gemini and local Ollama models
- **Custom Shell Integration**: Deep integration with macOS shell environments

## Installation

### Homebrew (Coming Soon)

```bash
brew tap lakshbharani/nux
brew install --cask nux
```

### Manual Installation

1. Download the latest release from [GitHub Releases](https://github.com/lakshbharani/nux/releases)
2. Extract the application bundle
3. Drag `nux.app` to your Applications folder
4. Launch and grant necessary permissions

## AI Configuration

1. Open nux Settings (⌘,)
2. Configure API keys for your preferred AI providers:
   - **Google Gemini**: Get your API key from [Google AI Studio](https://makersuite.google.com/app/apikey)
   - **Ollama**: Install locally with `brew install ollama` and run `ollama serve`
3. Customize AI behavior and response styles

## Development

### Building from Source

```bash
git clone https://github.com/lakshbharani/nux.git
cd nux
open nux.xcodeproj
```

Select the nux scheme and press Run (⌘R) in Xcode.

### Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later
- Apple Silicon (M1/M2/M3) or Intel x86_64

## Architecture

```
nux/
├── TerminalView.swift          # Main terminal interface
├── TerminalSession.swift       # Command execution and session state
├── AIContextManager.swift      # AI conversation and context management
├── LLMProvider.swift           # AI provider abstraction
├── ThemeManager.swift          # Theme system and persistence
├── AutocompleteEngine.swift    # Smart command suggestions
└── SettingsView.swift          # Configuration and preferences
```

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

- Follow existing SwiftUI patterns and Swift style guidelines
- Include unit tests for new functionality
- Update documentation for new features
- Ensure new features don't impact terminal responsiveness

## Roadmap

### Short-term (3-6 months)

- Command palette with fuzzy search
- Rich previews for images and documents
- Window persistence across launches
- Enhanced theme customization

### Medium-term (6-12 months)

- Agentic workflows with multi-step automation
- Direct tool integration (git, deployment systems)
- Collaboration features and shared sessions
- Advanced AI models and specialized assistants

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- 🐛 **Bug Reports**: [GitHub Issues](https://github.com/lakshbharani/nux/issues)
- 💡 **Feature Requests**: [GitHub Discussions](https://github.com/lakshbharani/nux/discussions)
- 📖 **Documentation**: [Wiki](https://github.com/lakshbharani/nux/wiki)

---

**nux** - Where the terminal meets intelligence, and development becomes conversation.
