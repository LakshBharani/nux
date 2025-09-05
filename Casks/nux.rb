cask "nux" do
  desc "Native macOS terminal built with SwiftUI - calm, fast experience with AI integration"
  homepage "https://github.com/LakshBharani/nux"
  version "1.0.0"
  sha256 "a7141e4bfb09073c8c08f068d151eedd16cd06182fc8eac8bb567bc4261faff2" # You'll need to update this after creating a release
  
  url "https://github.com/LakshBharani/nux/releases/download/v#{version}/nux-v#{version}.zip"
  name "nux"
  
  app "nux.app"
  
  zap trash: [
    "~/Library/Preferences/com.lakshbharani.nux.plist",
    "~/Library/Application Support/nux",
    "~/Library/Caches/com.lakshbharani.nux"
  ]
  
  caveats <<~EOS
    nux requires macOS 14+ (Sonoma).
    
    After installation, you can launch nux from your Applications folder.
  EOS
end
