//
//  TestView.swift
//  EarthLord
//
//  Created by Joy周 on 2025/12/26.
//

import SwiftUI

struct TestView: View {
    var body: some View {
        ZStack {
            Color.blue.opacity(0.2)
                .ignoresSafeArea()

            Text("这里是分支宇宙的测试页")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
        }
    }
}

#Preview {
    TestView()
}
