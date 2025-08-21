import SwiftUI

struct DirectoryInfoView: View {
    let fileContext: FileContext?
    let onShowDirectoryBrowser: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        if let context = fileContext {
            Button(action: onShowDirectoryBrowser) {
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .foregroundColor(themeManager.currentTheme.accentColor)
                        .font(.system(size: 12))
                    
                    Text(URL(fileURLWithPath: context.currentDirectory).lastPathComponent)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(themeManager.currentTheme.foregroundColor)
                    
                    Text("•")
                        .font(.system(size: 10))
                        .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.4))
                    
                    Text(context.summary)
                        .font(.system(size: 11))
                        .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.6))
                    
                    if let size = context.totalSize {
                        Text("• \(size)")
                            .font(.system(size: 11))
                            .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.6))
                    }
                    
                    // Click indicator
                    Image(systemName: "chevron.up")
                        .font(.system(size: 8))
                        .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.4))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    @StateObject var themeManager = ThemeManager()
    
    return DirectoryInfoView(
        fileContext: FileContext(currentDirectory: "/Users/test"),
        onShowDirectoryBrowser: { }
    )
    .environmentObject(themeManager)
    .padding()
}
