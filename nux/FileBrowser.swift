import SwiftUI

struct FileBrowser: View {
    let currentDirectory: String
    let onFileSelected: (String) -> Void
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    
    @State private var files: [FileItem] = []
    @State private var isLoading = true
    @State private var searchText = ""
    
    struct FileItem: Identifiable {
        let id = UUID()
        let name: String
        let path: String
        let isDirectory: Bool
        let size: String?
        let modifiedDate: Date?
        
        var icon: String {
            if isDirectory {
                return "folder.fill"
            } else {
                let ext = URL(fileURLWithPath: name).pathExtension.lowercased()
                switch ext {
                case "pdf": return "doc.richtext"
                case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "svg", "webp": return "photo"
                case "mp4", "mov", "avi", "mkv": return "video"
                case "mp3", "wav", "aac", "flac": return "music.note"
                case "txt", "md", "json", "xml", "html", "css", "js", "py", "swift", "java", "c", "cpp", "h", "hpp", "sh", "zsh", "bash", "yaml", "yml", "toml", "ini", "conf", "log": return "doc.text"
                default: return "doc"
                }
            }
        }
    }
    
    var filteredFiles: [FileItem] {
        if searchText.isEmpty {
            return files
        } else {
            return files.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.6))
                    
                    TextField("Search files...", text: $searchText)
                        .textFieldStyle(.plain)
                        .foregroundColor(themeManager.currentTheme.foregroundColor)
                    
                    if !searchText.isEmpty {
                        Button("Clear") {
                            searchText = ""
                        }
                        .foregroundColor(themeManager.currentTheme.accentColor)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(themeManager.currentTheme.backgroundColor.opacity(0.5))
                
                // File list
                if isLoading {
                    loadingView
                } else if files.isEmpty {
                    emptyView
                } else {
                    fileListView
                }
            }
            .navigationTitle(URL(fileURLWithPath: currentDirectory).lastPathComponent)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .background(themeManager.currentTheme.backgroundColor)
        .onAppear {
            Task {
                await loadFiles()
            }
        }
    }
    
    private var loadingView: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading files...")
                .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.7))
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeManager.currentTheme.backgroundColor)
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder")
                .font(.system(size: 48))
                .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.6))
            
            Text("No Files Found")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(themeManager.currentTheme.foregroundColor)
            
            Text("This directory appears to be empty.")
                .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeManager.currentTheme.backgroundColor)
    }
    
    private var fileListView: some View {
        List(filteredFiles) { file in
            Button(action: {
                onFileSelected(file.path)
                dismiss()
            }) {
                HStack(spacing: 12) {
                    Image(systemName: file.icon)
                        .foregroundColor(file.isDirectory ? themeManager.currentTheme.accentColor : themeManager.currentTheme.foregroundColor.opacity(0.8))
                        .font(.system(size: 16))
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(file.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(themeManager.currentTheme.foregroundColor)
                        
                        if let size = file.size {
                            Text(size)
                                .font(.system(size: 11))
                                .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.6))
                        }
                    }
                    
                    Spacer()
                    
                    if let date = file.modifiedDate {
                        Text(formatDate(date))
                            .font(.system(size: 11))
                            .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.6))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
        .background(themeManager.currentTheme.backgroundColor)
    }
    
    private func loadFiles() async {
        isLoading = true
        
            do {
                let fileManager = FileManager.default
                let contents = try fileManager.contentsOfDirectory(atPath: currentDirectory)
                
                var fileItems: [FileItem] = []
                
                for item in contents {
                    let fullPath = URL(fileURLWithPath: currentDirectory).appendingPathComponent(item).path
                    
                    var isDirectory: ObjCBool = false
                    let exists = fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory)
                    
                    if exists {
                        let attributes = try? fileManager.attributesOfItem(atPath: fullPath)
                        let size = attributes?[.size] as? Int64
                        let modifiedDate = attributes?[.modificationDate] as? Date
                        
                        let sizeString = size != nil ? formatFileSize(size!) : nil
                        
                        let fileItem = FileItem(
                            name: item,
                            path: fullPath,
                            isDirectory: isDirectory.boolValue,
                            size: sizeString,
                            modifiedDate: modifiedDate
                        )
                        
                        fileItems.append(fileItem)
                    }
                }
                
                // Sort: directories first, then files, both alphabetically
                fileItems.sort { item1, item2 in
                    if item1.isDirectory != item2.isDirectory {
                        return item1.isDirectory
                    }
                    return item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedAscending
                }
                
                self.files = fileItems
                self.isLoading = false
            } catch {
                self.files = []
                self.isLoading = false
            }
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    FileBrowser(
        currentDirectory: "/tmp",
        onFileSelected: { _ in }
    )
    .environmentObject(ThemeManager())
}
