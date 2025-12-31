//
//  LanguageManager.swift
//  EarthLord
//
//  语言管理器 - 处理 App 内语言切换
//

import Foundation
import SwiftUI
import Combine

// MARK: - 支持的语言
enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"      // 跟随系统
    case chinese = "zh-Hans"    // 简体中文
    case english = "en"         // English

    var id: String { rawValue }

    /// 本地化显示名称（使用 LocalizedStringKey 以支持自动翻译）
    var localizedName: LocalizedStringKey {
        switch self {
        case .system:
            return "跟随系统"
        case .chinese:
            return "简体中文"
        case .english:
            return "English"
        }
    }
}

// MARK: - LanguageManager
@MainActor
final class LanguageManager: ObservableObject {

    // MARK: - Singleton
    static let shared = LanguageManager()

    // MARK: - Published Properties

    /// 当前选择的语言设置
    @Published var selectedLanguage: AppLanguage {
        didSet {
            print("🌐 [语言] 语言设置已更改: \(oldValue.rawValue) -> \(selectedLanguage.rawValue)")
            saveLanguagePreference()
            updateLocale()
        }
    }

    /// 当前实际使用的 Locale
    @Published var currentLocale: Locale

    // MARK: - Private Properties

    private let languageKey = "app_language_preference"

    // MARK: - Initialization

    private init() {
        // 1. 从 UserDefaults 读取保存的语言设置
        let savedLanguage = UserDefaults.standard.string(forKey: languageKey) ?? AppLanguage.system.rawValue
        let language = AppLanguage(rawValue: savedLanguage) ?? .system

        self.selectedLanguage = language
        self.currentLocale = Self.resolveLocale(for: language)

        print("🌐 [语言] 初始化完成，当前设置: \(language.rawValue)")
        print("🌐 [语言] 当前 Locale: \(currentLocale.identifier)")
    }

    // MARK: - Public Methods

    /// 切换语言
    func setLanguage(_ language: AppLanguage) {
        guard language != selectedLanguage else { return }
        selectedLanguage = language
    }

    /// 获取当前语言的 Locale
    static func resolveLocale(for language: AppLanguage) -> Locale {
        switch language {
        case .system:
            // 跟随系统语言
            return Locale.current
        case .chinese:
            return Locale(identifier: "zh-Hans")
        case .english:
            return Locale(identifier: "en")
        }
    }

    // MARK: - Private Methods

    /// 保存语言偏好
    private func saveLanguagePreference() {
        UserDefaults.standard.set(selectedLanguage.rawValue, forKey: languageKey)
        print("🌐 [语言] 已保存语言偏好: \(selectedLanguage.rawValue)")
    }

    /// 更新当前 Locale
    private func updateLocale() {
        let newLocale = Self.resolveLocale(for: selectedLanguage)
        currentLocale = newLocale
        print("🌐 [语言] Locale 已更新: \(newLocale.identifier)")
    }
}

// MARK: - View Extension
extension View {
    /// 应用当前语言设置
    func applyLanguage() -> some View {
        self.modifier(LanguageModifier())
    }
}

// MARK: - Language Modifier
struct LanguageModifier: ViewModifier {
    @ObservedObject private var languageManager = LanguageManager.shared

    func body(content: Content) -> some View {
        content
            .environment(\.locale, languageManager.currentLocale)
    }
}
