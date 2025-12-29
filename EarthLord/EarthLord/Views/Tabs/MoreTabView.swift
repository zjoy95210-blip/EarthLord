//
//  MoreTabView.swift
//  EarthLord
//
//  Created by Joy周 on 2025/12/26.
//

import SwiftUI

struct MoreTabView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("开发者工具") {
                    NavigationLink {
                        SupabaseTestView()
                    } label: {
                        Label("Supabase 连接测试", systemImage: "server.rack")
                    }
                }

                Section("关于") {
                    Label("版本 1.0.0", systemImage: "info.circle")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("更多")
        }
    }
}

#Preview {
    MoreTabView()
}
