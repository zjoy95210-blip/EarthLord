//
//  MainTabView.swift
//  EarthLord
//
//  Created by Joy周 on 2025/12/26.
//

import SwiftUI

/// 主Tab页面 - 包含5个核心功能模块
struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // 地图 - 探索和圈占领地
            MapTabView()
                .tabItem {
                    Image(systemName: "map.fill")
                    Text("地图")
                }
                .tag(0)

            // 领地 - 管理已圈占的领地
            TerritoryTabView()
                .tabItem {
                    Image(systemName: "flag.fill")
                    Text("领地")
                }
                .tag(1)

            // 资源 - 背包和物资管理
            ResourcesTabView()
                .tabItem {
                    Image(systemName: "shippingbox.fill")
                    Text("资源")
                }
                .tag(2)

            // 个人 - 幸存者档案
            ProfileTabView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("个人")
                }
                .tag(3)

            // 通讯 - 无线电频道
            CommunicationTabView()
                .tabItem {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                    Text("通讯")
                }
                .tag(4)
        }
        .tint(ApocalypseTheme.primary)
    }
}

#Preview {
    MainTabView()
}
