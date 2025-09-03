class Nux < Cask
  desc "Native macOS terminal built with SwiftUI - calm, fast experience with AI integration"
  homepage "https://github.com/yourusername/nux"
  version "1.0.0"
  sha256 "YOUR_SHA256_HERE" # You'll need to update this after creating a release
  
  url "https://github.com/yourusername/nux/releases/download/v#{version}/nux-#{version}.zip"
  name "nux"
  
  app "nux.app"
  
  zap trash: [
    "~/Library/Preferences/com.yourusername.nux.plist",
    "~/Library/Application Support/nux",
    "~/Library/Caches/com.yourusername.nux"
  ]
  
  caveats <<~EOS
    nux requires macOS 14+ (Sonoma).
    
    After installation, you can launch nux from your Applications folder.
  EOS
end
