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

        // 加载建筑模板（验证建造系统）
        Task {
            do {
                try await BuildingManager.shared.loadTemplates()
                print("✅ 模板加载成功: \(BuildingManager.shared.templates.count) 个")
            } catch {
                print("❌ 模板加载失败: \(error)")
            }
        }
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
