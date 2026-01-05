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
                // Supabase 连接测试
                NavigationLink {
                    SupabaseTestView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 20))
                            .foregroundColor(ApocalypseTheme.primary)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Supabase 连接测试")
                                .font(.body)
                                .foregroundColor(ApocalypseTheme.textPrimary)

                            Text("测试后端数据库连接")
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // 圈地功能测试
                NavigationLink {
                    TerritoryTestView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "location.viewfinder")
                            .font(.system(size: 20))
                            .foregroundColor(ApocalypseTheme.primary)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("圈地功能测试")
                                .font(.body)
                                .foregroundColor(ApocalypseTheme.textPrimary)

                            Text("查看圈地模块调试日志")
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("开发者工具")
            }

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
