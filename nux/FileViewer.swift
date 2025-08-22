import SwiftUI
import AppKit
import PDFKit
import UniformTypeIdentifiers

struct FileViewer: View {
    let filePath: String
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    @State private var fileContent: String = ""
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showVimEditor = false
    @State private var fileType: FileType = .unknown
    
    enum FileType {
        case text
        case pdf
        case image
        case binary
        case unknown
        
        static func determine(for path: String) -> FileType {
            let url = URL(fileURLWithPath: path)
            let fileExtension = url.pathExtension.lowercased()
            
            // Text files
            let textExtensions = ["txt", "md", "json", "xml", "html", "css", "js", "py", "swift", "java", "c", "cpp", "h", "hpp", "sh", "zsh", "bash", "yaml", "yml", "toml", "ini", "conf", "log"]
            if textExtensions.contains(fileExtension) {
                return .text
            }
            
            // PDF files
            if fileExtension == "pdf" {
                return .pdf
            }
            
            // Image files
            let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "svg", "webp"]
            if imageExtensions.contains(fileExtension) {
                return .image
            }
            
            // Check if it's a text file by reading first few bytes
            if let data = try? Data(contentsOf: url, options: .alwaysMapped) {
                if data.count > 0 {
                    // Check if it's text by looking for null bytes
                    let nullByteCount = data.prefix(1024).filter { $0 == 0 }.count
                    if nullByteCount < 10 { // Less than 1% null bytes suggests text
                        return .text
                    }
                }
            }
            
            return .binary
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else {
                    contentView
                }
            }
            .navigationTitle(URL(fileURLWithPath: filePath).lastPathComponent)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                
                if fileType == .text {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Edit in Vim") {
                            showVimEditor = true
                        }
                    }
                }
            }
        }
        .onAppear {
            Task {
                await loadFile()
            }
        }
        .sheet(isPresented: $showVimEditor) {
            VimEditor(filePath: filePath, onExit: {})
                .environmentObject(themeManager)
        }
    }
    
    private var loadingView: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading file...")
                .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.7))
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeManager.currentTheme.backgroundColor)
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(themeManager.currentTheme.errorColor)
            
            Text("Error Loading File")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(themeManager.currentTheme.foregroundColor)
            
            Text(error)
                .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeManager.currentTheme.backgroundColor)
    }
    
    private var contentView: some View {
        Group {
            switch fileType {
            case .text:
                textContentView
            case .pdf:
                PDFViewer(filePath: filePath)
            case .image:
                ImageViewer(filePath: filePath)
            case .binary:
                binaryContentView
            case .unknown:
                unknownContentView
            }
        }
        .background(themeManager.currentTheme.backgroundColor)
    }
    
    private var textContentView: some View {
        ScrollView {
            Text(fileContent)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(themeManager.currentTheme.foregroundColor)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .background(themeManager.currentTheme.backgroundColor)
    }
    
    private var binaryContentView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.binary")
                .font(.system(size: 48))
                .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.6))
            
            Text("Binary File")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(themeManager.currentTheme.foregroundColor)
            
            Text("This appears to be a binary file and cannot be displayed as text.")
                .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeManager.currentTheme.backgroundColor)
    }
    
    private var unknownContentView: some View {
        VStack(spacing: 16) {
            Image(systemName: "questionmark.folder")
                .font(.system(size: 48))
                .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.6))
            
            Text("Unknown File Type")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(themeManager.currentTheme.foregroundColor)
            
            Text("Unable to determine the file type for this file.")
                .foregroundColor(themeManager.currentTheme.foregroundColor.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeManager.currentTheme.backgroundColor)
    }
    
    private func loadFile() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let url = URL(fileURLWithPath: filePath)
            
            // Determine file type
            let determinedType = FileType.determine(for: filePath)
            
            self.fileType = determinedType
            
            // Load content based on type
            switch determinedType {
            case .text:
                let content = try String(contentsOf: url, encoding: .utf8)
                self.fileContent = content
                self.isLoading = false
            case .pdf, .image:
                // These will be handled by their respective viewers
                self.isLoading = false
            case .binary, .unknown:
                self.isLoading = false
            }
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }
    

}

// MARK: - PDF Viewer
struct PDFViewer: NSViewRepresentable {
    let filePath: String
    
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        return pdfView
    }
    
    func updateNSView(_ pdfView: PDFView, context: Context) {
        if let url = URL(string: "file://" + filePath),
           let document = PDFDocument(url: url) {
            pdfView.document = document
        }
    }
}

// MARK: - Image Viewer
struct ImageViewer: NSViewRepresentable {
    let filePath: String
    
    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignCenter
        return imageView
    }
    
    func updateNSView(_ imageView: NSImageView, context: Context) {
        if let image = NSImage(contentsOfFile: filePath) {
            imageView.image = image
        }
    }
}

#Preview {
    FileViewer(filePath: "/tmp/test.txt")
        .environmentObject(ThemeManager())
}
