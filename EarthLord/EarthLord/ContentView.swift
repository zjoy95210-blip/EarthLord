//
//  ContentView.swift
//  EarthLord
//
//  Created by 周小红 on 2025/12/26.
//

import SwiftUI

/// 主内容视图 - 包含5个Tab的TabView
/// - 地图（MapTabView）- 图标 map.fill
/// - 领地（TerritoryTabView）- 图标 flag.fill
/// - 资源（ResourcesTabView）- 图标 shippingbox.fill
/// - 个人（ProfileTabView）- 图标 person.fill
/// - 通讯（CommunicationTabView）- 图标 antenna.radiowaves.left.and.right
struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: 地图 - 探索和圈占领地
            MapTabView()
                .tabItem {
                    Image(systemName: "map.fill")
                    Text("地图")
                }
                .tag(0)

            // Tab 2: 领地 - 管理已圈占的领地
            TerritoryTabView()
                .tabItem {
                    Image(systemName: "flag.fill")
                    Text("领地")
                }
                .tag(1)

            // Tab 3: 资源 - 背包和物资管理
            ResourcesTabView()
                .tabItem {
                    Image(systemName: "shippingbox.fill")
                    Text("资源")
                }
                .tag(2)

            // Tab 4: 个人 - 幸存者档案
            ProfileTabView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("个人")
                }
                .tag(3)

            // Tab 5: 通讯 - 无线电频道
            CommunicationTabView()
                .tabItem {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                    Text("通讯")
                }
                .tag(4)

            // Tab 6: 更多 - 开发测试入口
            MoreTabView()
                .tabItem {
                    Image(systemName: "ellipsis.circle.fill")
                    Text("更多")
                }
                .tag(5)
        }
        .tint(ApocalypseTheme.primary)
    }
}

#Preview {
    ContentView()
}
