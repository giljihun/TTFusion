//
//  ContentView.swift
//  TTFusion
//
//  Created by 길지훈 on 2/24/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "widget.small")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("위젯을 확인하세요!")
                .font(.title2)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    ContentView()
}
