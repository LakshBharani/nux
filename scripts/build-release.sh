#!/bin/bash

# Build script for nux releases
set -e

VERSION=${1:-"1.0.0"}
BUILD_DIR="build"
RELEASE_DIR="release"

echo "Building nux version $VERSION..."

# Clean previous builds
rm -rf "$BUILD_DIR"
rm -rf "$RELEASE_DIR"

# Build the project
xcodebuild -project nux.xcodeproj \
           -scheme nux \
           -configuration Release \
           SYMROOT="$BUILD_DIR" \
           CODE_SIGN_IDENTITY="" \
           CODE_SIGNING_REQUIRED=NO \
           CODE_SIGNING_ALLOWED=NO

# Create release directory
mkdir -p "$RELEASE_DIR"

# Copy the built app
cp -R "$BUILD_DIR/Release/nux.app" "$RELEASE_DIR/"

# Create a zip archive for distribution
cd "$RELEASE_DIR"
zip -r "nux-$VERSION.zip" "nux.app"
cd ..

echo "Build complete!"
echo "Release files are in: $RELEASE_DIR/"
echo "App bundle: $RELEASE_DIR/nux.app"
echo "Zip archive: $RELEASE_DIR/nux-$VERSION.zip"

# Calculate SHA256 for Homebrew formula
echo ""
echo "SHA256 for Homebrew formula:"
shasum -a 256 "$RELEASE_DIR/nux-$VERSION.zip"
