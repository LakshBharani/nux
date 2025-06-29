//
//  ContentView.swift
//  nux
//
//  Created by Laksh Bharani on 6/18/25.
//

import SwiftUI

struct ContentView: View {
    @Binding var selectedModel: AIModel
    @State private var terminalHistory: [TerminalEntry] = []
    @State private var isAIAssistEnabled = false

    var body: some View {
        ZStack {
            VisualEffectView(material: .fullScreenUI)
                .frame(width: windowSize.width, height: windowSize.height)
            
            Color.black.opacity(0.35)
            
            VStack(spacing: 0) {
                Header(isAIAssistEnabled: $isAIAssistEnabled)
                
                Divider()
                
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(terminalHistory) { entry in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(entry.status)")
                                        .foregroundStyle(.green)
                                        .font(.system(size: 12, design: .monospaced))
                                    Text("> \(entry.input)")
                                        .foregroundStyle(.white)
                                    if !entry.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        Text(entry.output)
                                            .foregroundStyle(.white.opacity(0.65))
                                            .shimmer(if: entry.output == "Thinking...")
                                    }
                                }
                                .padding()
                                Divider()
                            }


                            Color.clear
                                .frame(height: 1)
                                .id("bottom")
                        }
                        .frame(maxWidth: .greatestFiniteMagnitude, alignment: .leading)
                        
                    }
                    .onChange(of: terminalHistory.count) { oldCount, newCount in
                        withAnimation {
                            scrollProxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }

                }

                
                Divider()
                
                ScriptInputField(selectedModel: $selectedModel, terminalHistory: $terminalHistory, isAIAssistEnabled: $isAIAssistEnabled)
                
                
            }
            .frame(width: windowSize.width)
            
        }
        .font(.system(size: 14, design: .monospaced))
        .frame(width: windowSize.width, height: windowSize.height)
    }
}

struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = -200

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(gradient: Gradient(colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.6), Color.gray.opacity(0.2)]),
                               startPoint: .leading,
                               endPoint: .trailing)
                    .frame(width: 200)
                    .offset(x: phase)
                    .mask(content)
            )
            .onAppear {
                withAnimation(Animation.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                    phase = 200
                }
            }
    }
}

extension View {
    @ViewBuilder
    func shimmer(if condition: Bool) -> some View {
        if condition {
            self.modifier(Shimmer())
        } else {
            self
        }
    }
}





#Preview {
    ContentView(selectedModel: .constant(AIModel.gemini))
}



