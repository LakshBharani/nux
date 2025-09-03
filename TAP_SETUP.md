# Setting Up Your Homebrew Tap for nux

This guide will help you create your own Homebrew tap to distribute nux.

## What is a Homebrew Tap?

A tap is a Git repository containing Homebrew formulae/casks. It's the easiest way to distribute your own applications without going through the main Homebrew repository approval process.

## Step 1: Create the Tap Repository

1. Go to GitHub and create a new repository named `homebrew-tap`
2. Make it public
3. Clone it locally:

```bash
git clone https://github.com/yourusername/homebrew-tap.git
cd homebrew-tap
```

## Step 2: Add the nux Cask

1. Copy the `Casks/nux.rb` file from this project to your tap repository:

```bash
# From the nux project directory
cp Casks/nux.rb /path/to/homebrew-tap/Casks/
```

2. Update the cask file with your actual GitHub username and correct SHA256

## Step 3: Commit and Push

```bash
cd /path/to/homebrew-tap
git add Casks/nux.rb
git commit -m "Add nux cask"
git push origin main
```

## Step 4: Test the Installation

```bash
# Test locally first
brew install --cask /path/to/homebrew-tap/Casks/nux.rb

# Then test via tap
brew tap yourusername/tap
brew install --cask nux
```

## Step 5: Update the nux Project

1. Update the README.md in this project with your actual GitHub username
2. Update the cask file with your actual GitHub username
3. Commit and push the changes

## Maintaining Your Tap

### When you release a new version:

1. Update the version number in `Casks/nux.rb`
2. Update the SHA256 hash
3. Update the URL if needed
4. Commit and push the changes

### Example workflow:

```bash
# After creating a new release
cd homebrew-tap
# Update Casks/nux.rb with new version and SHA256
git add Casks/nux.rb
git commit -m "Update nux to v1.1.0"
git push origin main
```

## Benefits of Using a Tap

- ✅ **Fast**: No approval process needed
- ✅ **Control**: You control when and how to update
- ✅ **Free**: No costs involved
- ✅ **Flexible**: Can include multiple applications
- ✅ **Easy**: Simple Git-based workflow

## Troubleshooting

### Common Issues:

1. **"No available formula"**: Make sure the tap is added correctly
2. **SHA256 mismatch**: Verify the hash matches your release file
3. **Download failed**: Check that the GitHub release URL is correct

### Getting Help:

- Homebrew documentation: https://docs.brew.sh/
- Homebrew tap examples: https://github.com/search?q=homebrew-tap
- Homebrew community: https://github.com/Homebrew/brew/discussions
