//
//  EarthLordApp.swift
//  EarthLord
//
//  Created by 周小红 on 2025/12/26.
//

import SwiftUI
import GoogleSignIn

@main
struct EarthLordApp: App {

    init() {
        // 配置全局 TabBar 和 NavigationBar 外观
        ApocalypseTheme.configureAppearance()
        print("🚀 [App] EarthLord 启动")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .onOpenURL { url in
                    // 处理 Google Sign-In URL 回调
                    print("🔗 [App] 收到 URL 回调: \(url)")
                    let handled = GIDSignIn.sharedInstance.handle(url)
                    print("🔗 [App] Google Sign-In 处理结果: \(handled ? "成功" : "未处理")")
                }
        }
    }
}
