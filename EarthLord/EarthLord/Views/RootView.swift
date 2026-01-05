//
//  RootView.swift
//  EarthLord
//
//  Created by Joy周 on 2025/12/26.
//

import SwiftUI

/// 根视图：控制启动页、认证页、主界面的切换
struct RootView: View {
    /// 启动页是否完成
    @State private var splashFinished = false

    /// 认证管理器（使用共享实例）
    @ObservedObject private var authManager = AuthManager.shared

    /// 语言管理器（使用共享实例）
    @ObservedObject private var languageManager = LanguageManager.shared

    var body: some View {
        ZStack {
            if !splashFinished {
                // 启动页
                SplashView(authManager: authManager, isFinished: $splashFinished)
                    .transition(.opacity)
            } else if !authManager.isAuthenticated {
                // 未认证：显示登录/注册页
                AuthView()
                    .transition(.opacity)
            } else {
                // 已认证：显示主界面
                MainTabView()
                    .transition(.opacity)
                    .environmentObject(authManager)
                    .environmentObject(LocationManager.shared)
            }
        }
        .environment(\.locale, languageManager.currentLocale)
        .animation(.easeInOut(duration: 0.3), value: splashFinished)
        .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
    }
}

#Preview {
    RootView()
}
