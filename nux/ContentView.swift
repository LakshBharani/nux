//
//  ContentView.swift
//  nux
//
//  Created by Laksh Bharani on 6/18/25.
//

import SwiftUI

struct ContentView: View {
    @State private var terminalHistory: [TerminalEntry] = []

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow)
                .frame(width: windowSize.width, height: windowSize.height)
            
            VStack(spacing: 0) {
                Header()
                
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
                                            .foregroundStyle(.gray)
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
                
                ScriptInputField(terminalHistory: $terminalHistory)
                
                
            }
            .frame(width: windowSize.width)
            
        }
        .font(.system(size: 14, design: .monospaced))
        .frame(width: windowSize.width, height: windowSize.height)
    }
}



#Preview {
    ContentView()
}



