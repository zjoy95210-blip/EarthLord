//
//  EarthLordApp.swift
//  EarthLord
//
//  Created by 周小红 on 2025/12/26.
//

import SwiftUI

@main
struct EarthLordApp: App {

    init() {
        // 配置全局 TabBar 和 NavigationBar 外观
        ApocalypseTheme.configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
