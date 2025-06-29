//
//  SwiftUIView.swift
//  nux
//
//  Created by Laksh Bharani on 6/18/25.
//

import SwiftUI

struct TerminalEntry: Identifiable {
    let id = UUID()
    var status: String
    var input: String
    var output: String
    var isAI: Bool = false
    var isPending: Bool = false
}

struct ScriptInputField: View {
    @Binding var selectedModel: AIModel
    @Binding var terminalHistory: [TerminalEntry]
    @Binding var isAIAssistEnabled: Bool

    @State private var script = ""
    @State private var currentDirectory: String = FileManager.default.homeDirectoryForCurrentUser.path

    func getSystemShellPath() -> String {
        let process = Process()
        process.launchPath = "/bin/zsh"
        process.arguments = ["-l", "-c", "echo $PATH"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.launch()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    func tryChangeDirectory(_ command: String) -> Bool {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == "cd" || trimmed.hasPrefix("cd ") else { return false }

        let newPath = trimmed == "cd"
            ? FileManager.default.homeDirectoryForCurrentUser.path
            : String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)

        let fullPath = newPath.hasPrefix("/")
            ? newPath
            : (currentDirectory as NSString).appendingPathComponent(newPath)

        let resolvedPath = URL(fileURLWithPath: fullPath).standardized.path
        var isDir: ObjCBool = false

        if FileManager.default.fileExists(atPath: resolvedPath, isDirectory: &isDir), isDir.boolValue {
            currentDirectory = resolvedPath
            terminalHistory.append(TerminalEntry(status: resolvedPath, input: "cd \(newPath)", output: ""))
        } else {
            terminalHistory.append(TerminalEntry(status: currentDirectory, input: "cd \(newPath)", output: "cd: no such file or directory: \(newPath)"))
        }

        return true
    }

    func runShellCommand(_ command: String, in directory: String) -> String {
        let process = Process()
        process.launchPath = "/bin/zsh"
        process.arguments = ["-c", command]
        process.currentDirectoryPath = directory

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        process.environment = ["PATH": getSystemShellPath()]

        process.launch()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(decoding: data, as: UTF8.self)
    }

    func handleInput() {
        let trimmed = script.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let userInput = script
        script = ""

        if isAIAssistEnabled {
            let pendingID = UUID()
            terminalHistory.append(
                TerminalEntry(status: currentDirectory, input: userInput, output: "Thinking...", isAI: true, isPending: true)
            )

            getAICommand(for: userInput) { aiCommand in
                DispatchQueue.main.async {
                    if tryChangeDirectory(aiCommand) {
                        terminalHistory.removeAll { $0.id == pendingID }
                        return
                    }

                    DispatchQueue.global(qos: .userInitiated).async {
                        let result = runShellCommand(aiCommand, in: currentDirectory)
                        let statusLine = "\(currentDirectory) (\(String(format: "%.2f", Date().timeIntervalSinceNow * -1))s)"

                        DispatchQueue.main.async {
                            if let index = terminalHistory.firstIndex(where: { $0.id == pendingID }) {
                                terminalHistory[index] = TerminalEntry(
                                    status: statusLine,
                                    input: "\(userInput) → \(aiCommand)",
                                    output: result,
                                    isAI: true,
                                    isPending: false
                                )
                            }
                        }
                    }
                }
            }
        } else {
            if tryChangeDirectory(trimmed) { return }

            let startTime = Date()
            DispatchQueue.global(qos: .userInitiated).async {
                let result = runShellCommand(userInput, in: currentDirectory)
                let elapsed = Date().timeIntervalSince(startTime)
                let statusLine = "\(currentDirectory) (\(String(format: "%.2f", elapsed))s)"

                DispatchQueue.main.async {
                    terminalHistory.append(TerminalEntry(status: statusLine, input: userInput, output: result))
                }
            }
        }
    }

    func getAICommand(for input: String, completion: @escaping (String) -> Void) {
        guard let url = URL(string: "http://localhost:8080/ai") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let subdirs: [String]
        do {
            let items = try FileManager.default.contentsOfDirectory(atPath: currentDirectory)
            subdirs = items.filter {
                var isDir: ObjCBool = false
                let fullPath = (currentDirectory as NSString).appendingPathComponent($0)
                return FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDir) && isDir.boolValue
            }
        } catch {
            subdirs = []
        }

        let body: [String: Any] = [
            "prompt": input,
            "directory": currentDirectory,
            "subdirectories": subdirs,
            "model": selectedModel.rawValue
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            return
        }

        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                  let command = json["command"] else { return }
            completion(command)
        }.resume()
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text(currentDirectory)
                .foregroundStyle(.purple)

            HStack {
                if isAIAssistEnabled {
                    Image(systemName: "sparkles").foregroundStyle(.yellow)
                } else {
                    Text(">").foregroundStyle(.green)
                }

                TextField(isAIAssistEnabled ? "AI Assist is ON" : "⌘ + K to toggle AI assist", text: $script)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.white)
                    .onSubmit { handleInput() }
            }
        }
        .padding()
        .onReceive(NotificationCenter.default.publisher(for: .toggleAIAssist)) { _ in
            isAIAssistEnabled.toggle()
        }
    }
}



extension Notification.Name {
    static let toggleAIAssist = Notification.Name("toggleAIAssist")
}

#Preview {
    ScriptInputField(selectedModel: .constant(AIModel.gemini), terminalHistory: .constant([]), isAIAssistEnabled: .constant(false))
}
