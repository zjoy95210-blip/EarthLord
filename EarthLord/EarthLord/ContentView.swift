//
//  ContentView.swift
//  EarthLord
//
//  Created by 周小红 on 2025/12/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("Hello, world!")

                Text("Developed by Joy周")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                NavigationLink("进入测试页") {
                    TestView()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
