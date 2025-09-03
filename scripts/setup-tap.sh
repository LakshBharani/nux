#!/bin/bash

# Setup script for Homebrew tap
set -e

echo "🚀 Setting up Homebrew tap for nux..."

# Check if we're in the right directory
if [ ! -f "Casks/nux.rb" ]; then
    echo "❌ Error: Casks/nux.rb not found. Run this script from the nux project root."
    exit 1
fi

echo "📋 What you need to do:"
echo ""
echo "1. Create a new GitHub repository named 'homebrew-tap'"
echo "   - Go to: https://github.com/new"
echo "   - Repository name: homebrew-tap"
echo "   - Make it public"
echo "   - Don't initialize with README, .gitignore, or license"
echo ""
echo "2. Clone the tap repository:"
echo "   git clone https://github.com/YOUR_USERNAME/homebrew-tap.git"
echo "   cd homebrew-tap"
echo ""
echo "3. Copy the nux cask:"
echo "   mkdir -p Casks"
echo "   cp /path/to/nux/Casks/nux.rb Casks/"
echo ""
echo "4. Update the cask file:"
echo "   - Replace 'yourusername' with your actual GitHub username"
echo "   - Update the SHA256 hash after creating a release"
echo ""
echo "5. Commit and push:"
echo "   git add Casks/nux.rb"
echo "   git commit -m 'Add nux cask'"
echo "   git push origin main"
echo ""
echo "6. Test the installation:"
echo "   brew tap YOUR_USERNAME/tap"
echo "   brew install --cask nux"
echo ""
echo "📚 See TAP_SETUP.md for detailed instructions"
echo ""
echo "🎯 Your tap will be available at: https://github.com/YOUR_USERNAME/homebrew-tap"
