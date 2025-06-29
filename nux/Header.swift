//
//  Header.swift
//  nux
//
//  Created by Laksh Bharani on 6/18/25.
//

import SwiftUI

struct Header: View {
    @Binding var isAIAssistEnabled: Bool
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.2)
            HStack {
                
            }
            
        }
        .frame(width: windowSize.width, height: 50)
    }
}

#Preview {
    Header(isAIAssistEnabled: .constant(false))
}
