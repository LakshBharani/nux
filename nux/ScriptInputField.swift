//
//  SwiftUIView.swift
//  nux
//
//  Created by Laksh Bharani on 6/18/25.
//

import SwiftUI

struct TerminalEntry: Identifiable {
    let id = UUID()
    let status: String
    let input: String
    let output: String
}

struct ScriptInputField: View {
    @Binding var terminalHistory: [TerminalEntry]
    @State private var script = ""
    @State private var currentDirectory: String = FileManager.default.homeDirectoryForCurrentUser.path
    @State private var isAIAssistEnabled = false


    func getSystemShellPath() -> String {
        let process = Process()
        process.launchPath = "/bin/zsh"
        process.arguments = ["-l", "-c", "echo $PATH"] // -l gets login shell env

        let pipe = Pipe()
        process.standardOutput = pipe
        process.launch()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }


    func runShellCommand(_ command: String, in directory: String) -> String {
        let process = Process()
        process.launchPath = "/bin/zsh"
        process.arguments = ["-c", command]
        process.currentDirectoryPath = directory

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        process.environment = [
               "PATH": getSystemShellPath()
           ]

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
            getAICommand(for: userInput) { aiCommand in
                let startTime = Date()
                DispatchQueue.global(qos: .userInitiated).async {
                    let result = runShellCommand(aiCommand, in: currentDirectory)
                    let elapsed = Date().timeIntervalSince(startTime)
                    let statusLine = "\(currentDirectory) (\(String(format: "%.2f", elapsed))s)"
                    
                    DispatchQueue.main.async {
                        terminalHistory.append(
                            TerminalEntry(
                                status: statusLine,
                                input: "\(userInput) → \(aiCommand)",
                                output: result
                            )
                        )
                    }
                }
            }
        } else {
            if trimmed == "cd" || trimmed.starts(with: "cd ") {
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
                    terminalHistory.append(
                        TerminalEntry(status: resolvedPath, input: userInput, output: "")
                    )
                } else {
                    terminalHistory.append(
                        TerminalEntry(status: currentDirectory, input: userInput, output: "cd: no such file or directory: \(newPath)")
                    )
                }
            } else {
                let startTime = Date()
                DispatchQueue.global(qos: .userInitiated).async {
                    let result = runShellCommand(userInput, in: currentDirectory)
                    let elapsed = Date().timeIntervalSince(startTime)
                    let statusLine = "\(currentDirectory) (\(String(format: "%.2f", elapsed))s)"
                    
                    DispatchQueue.main.async {
                        terminalHistory.append(
                            TerminalEntry(status: statusLine, input: userInput, output: result)
                        )
                    }
                }
            }
        }

        print(currentDirectory)
    }

    
    func getAICommand(for input: String, completion: @escaping (String) -> Void) {
        guard let url = URL(string: "http://localhost:8080/ai") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "prompt": input,
            "directory": currentDirectory
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                  let command = json["command"] else {
                return
            }
            completion(command)
        }.resume()
    }

    

    
    var body: some View {
        VStack(alignment: .leading) {
            Text(currentDirectory)
                .foregroundStyle(.purple)
            
            HStack {
                if (isAIAssistEnabled) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.yellow)
                } else {
                    Text(">")
                        .foregroundStyle(.green)
                }
                TextField(isAIAssistEnabled ? "AI Assist is ON" : "⌘ + K to toggle AI assist", text: $script)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.white)
                    .background(Color.clear)
                    .padding(.vertical, 4)
                    .foregroundColor(.green)
                    .onSubmit { handleInput() }
            }
        }
        .padding()
        .frame(width: windowSize.width, alignment: .leading)
        .onReceive(NotificationCenter.default.publisher(for: .toggleAIAssist)) { _ in
                isAIAssistEnabled.toggle()
            }
    }
}


extension Notification.Name {
    static let toggleAIAssist = Notification.Name("toggleAIAssist")
}

#Preview {
    ScriptInputField(terminalHistory: .constant([]))
}

