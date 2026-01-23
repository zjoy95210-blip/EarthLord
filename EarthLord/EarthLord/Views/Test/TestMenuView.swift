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
            // 开发者工具
            Section {
                NavigationLink {
                    DeveloperToolsView()
                } label: {
                    Label("开发者工具", systemImage: "wrench.and.screwdriver")
                }
            } header: {
                Text("调试工具")
            }

            // 功能测试
            Section {
                NavigationLink {
                    TerritoryTestView()
                } label: {
                    Label("领地测试", systemImage: "flag")
                }
            } header: {
                Text("功能测试")
            }

            // 关于
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
