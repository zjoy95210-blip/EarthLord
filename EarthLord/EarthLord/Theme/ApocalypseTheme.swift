//
//  ApocalypseTheme.swift
//  EarthLord
//
//  Created by Joy周 on 2025/12/26.
//

import SwiftUI

/// 末日主题配色
/// 主色：橙色 #FF6B35
/// 背景：深灰 #1A1A2E
/// 文字：浅灰 #E8E8E8
enum ApocalypseTheme {
    // MARK: - 主色调
    /// 主题橙色 #FF6B35
    static let primary = Color(hex: "FF6B35")
    /// 深橙色（用于按压状态等）
    static let primaryDark = Color(hex: "CC5629")

    // MARK: - 背景色
    /// 主背景 #1A1A2E
    static let background = Color(hex: "1A1A2E")
    /// 卡片/次级背景
    static let cardBackground = Color(hex: "252542")
    /// TabBar背景
    static let tabBarBackground = Color(hex: "0F0F1A")

    // MARK: - 文字色
    /// 主文字 #E8E8E8
    static let textPrimary = Color(hex: "E8E8E8")
    /// 次要文字
    static let textSecondary = Color(hex: "A0A0A0")
    /// 弱化文字
    static let textMuted = Color(hex: "666666")

    // MARK: - 状态色
    /// 成功/绿色
    static let success = Color(hex: "4CAF50")
    /// 警告/黄色
    static let warning = Color(hex: "FFC107")
    /// 危险/红色
    static let danger = Color(hex: "FF5252")
    /// 信息/蓝色
    static let info = Color(hex: "2196F3")

    // MARK: - 配置全局外观
    static func configureAppearance() {
        // 配置 TabBar 外观
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(tabBarBackground)

        // 未选中状态
        tabBarAppearance.stackedLayoutAppearance.normal.iconColor = UIColor(textSecondary)
        tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(textSecondary)
        ]

        // 选中状态
        tabBarAppearance.stackedLayoutAppearance.selected.iconColor = UIColor(primary)
        tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(primary)
        ]

        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance

        // 配置 NavigationBar 外观
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = UIColor(background)
        navBarAppearance.titleTextAttributes = [
            .foregroundColor: UIColor(textPrimary)
        ]
        navBarAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(textPrimary)
        ]

        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        UINavigationBar.appearance().tintColor = UIColor(primary)
    }
}

// MARK: - Color Hex Extension
extension Color {
    /// 从十六进制字符串创建颜色
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
