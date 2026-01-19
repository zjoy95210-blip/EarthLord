//
//  TestMenuView.swift
//  EarthLord
//
//  测试入口菜单 - 开发调试功能入口
//

import SwiftUI

struct TestMenuView: View {

    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    Text("版本 1.0.0")
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            } header: {
                Text("关于")
            }
        }
        .navigationTitle("开发测试")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        TestMenuView()
    }
}
