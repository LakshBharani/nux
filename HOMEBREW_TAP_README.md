# 🍺 nux Homebrew Tap Setup

## Overview

This project is configured to use a **Homebrew Tap** for distribution, which is the fastest and most flexible way to distribute your macOS applications.

## What Changed

- ✅ **Switched from Formula to Cask**: Better suited for GUI applications like nux
- ✅ **Moved to `Casks/` directory**: Follows Homebrew tap conventions
- ✅ **Updated installation instructions**: Users will use `brew tap` + `brew install --cask`
- ✅ **Added tap setup scripts**: Automated setup and maintenance

## Quick Start

### 1. Run the Setup Script

```bash
./scripts/setup-tap.sh
```

### 2. Create Your Tap Repository

- Go to GitHub and create `homebrew-tap` repository
- Copy `Casks/nux.rb` to your tap
- Update with your GitHub username and SHA256

### 3. Users Install With

```bash
brew tap yourusername/tap
brew install --cask nux
```

## File Structure

```
nux/
├── Casks/
│   └── nux.rb              # Homebrew cask for distribution
├── scripts/
│   ├── build-release.sh    # Builds release versions
│   └── setup-tap.sh        # Helps set up your tap
├── .github/workflows/
│   └── release.yml         # Automated releases
├── TAP_SETUP.md            # Detailed tap setup guide
└── HOMEBREW_TAP_README.md  # This file
```

## Benefits of Tap Approach

- 🚀 **Fast**: No approval process needed
- 🎯 **Control**: You control when and how to update
- 💰 **Free**: No costs involved
- 🔄 **Flexible**: Can include multiple applications
- 📦 **Simple**: Git-based workflow

## Workflow

1. **Develop** → Make changes to nux
2. **Release** → Create GitHub release (automated via Actions)
3. **Update Tap** → Update cask with new version and SHA256
4. **Deploy** → Users get updates via `brew upgrade nux`

## Next Steps

1. Run `./scripts/setup-tap.sh` for setup instructions
2. Create your `homebrew-tap` repository on GitHub
3. Copy and configure the cask file
4. Test the installation process
5. Share with users!

## Support

- 📚 **TAP_SETUP.md**: Detailed setup instructions
- 🛠️ **Makefile**: Common development tasks
- 📖 **README.md**: User-facing documentation
- 🔧 **Scripts**: Automated build and setup tools
