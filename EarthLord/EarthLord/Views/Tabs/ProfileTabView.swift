//
//  ProfileTabView.swift
//  EarthLord
//
//  Created by Joy周 on 2025/12/26.
//

import SwiftUI
import Supabase

struct ProfileTabView: View {
    /// 认证管理器
    @ObservedObject private var authManager = AuthManager.shared

    /// 语言管理器
    @ObservedObject private var languageManager = LanguageManager.shared

    /// 当前环境的 Locale
    @Environment(\.locale) private var locale

    /// 是否显示退出确认弹窗
    @State private var showLogoutAlert = false

    /// 是否显示删除账户确认弹窗
    @State private var showDeleteSheet = false

    /// 是否显示删除成功提示
    @State private var showDeleteSuccess = false

    /// 删除确认输入文本
    @State private var deleteConfirmText = ""

    /// 是否正在删除
    @State private var isDeleting = false

    /// 当前用户
    private var currentUser: User? {
        authManager.currentUser
    }

    /// 删除确认关键词（根据当前语言）
    private var deleteKeyword: String {
        let langCode = locale.language.languageCode?.identifier ?? "zh"
        return langCode.hasPrefix("zh") ? "删除" : "DELETE"
    }

    /// 是否可以删除（输入匹配关键词）
    private var canDelete: Bool {
        deleteConfirmText == deleteKeyword
    }

    var body: some View {
        NavigationStack {
            List {
                // 用户信息区域
                Section {
                    userInfoView
                }

                // 账户设置
                Section("账户") {
                    NavigationLink {
                        Text("编辑资料")
                    } label: {
                        Label("编辑资料", systemImage: "person.circle")
                    }

                    NavigationLink {
                        Text("修改密码")
                    } label: {
                        Label("修改密码", systemImage: "lock")
                    }
                }

                // 语言设置
                Section {
                    Picker(selection: $languageManager.selectedLanguage) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.localizedName)
                                .tag(language)
                        }
                    } label: {
                        Label {
                            Text("语言")
                        } icon: {
                            Image(systemName: "globe")
                        }
                    }
                } header: {
                    Text("语言")
                } footer: {
                    Text("切换语言后立即生效，无需重启 App")
                }

                // 开发者工具
                Section("开发调试") {
                    NavigationLink {
                        DeveloperToolsView()
                    } label: {
                        Label("开发者工具", systemImage: "wrench.and.screwdriver")
                    }
                }

                // 关于
                Section("关于") {
                    // 技术支持
                    Button {
                        if let url = URL(string: "https://zjoy95210-blip.github.io/earthlord-support/") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Label("技术支持", systemImage: "questionmark.circle")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.secondary)
                        }
                    }

                    // 隐私政策
                    Button {
                        if let url = URL(string: "https://zjoy95210-blip.github.io/earthlord-support/privacy.html") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Label("隐私政策", systemImage: "hand.raised")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // 游戏数据
                Section("游戏数据") {
                    HStack {
                        Label("领地数量", systemImage: "map")
                        Spacer()
                        Text("0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Label("发现的POI", systemImage: "mappin.and.ellipse")
                        Spacer()
                        Text("0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Label("总面积", systemImage: "square.dashed")
                        Spacer()
                        Text("0 m²")
                            .foregroundColor(.secondary)
                    }
                }

                // 退出登录
                Section {
                    Button(role: .destructive) {
                        showLogoutAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                            Spacer()
                        }
                    }
                }

                // 危险区域 - 删除账户
                Section {
                    Button(role: .destructive) {
                        print("🔴 [个人页] 用户点击删除账户按钮")
                        deleteConfirmText = ""  // 重置输入
                        showDeleteSheet = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("删除账户", systemImage: "trash")
                            Spacer()
                        }
                    }
                } footer: {
                    Text("删除账户后，所有数据将被永久删除且无法恢复。")
                        .font(.caption)
                }
            }
            .navigationTitle("个人")
            // 退出登录弹窗
            .alert("退出登录", isPresented: $showLogoutAlert) {
                Button("取消", role: .cancel) { }
                Button("退出", role: .destructive) {
                    Task {
                        await authManager.signOut()
                    }
                }
            } message: {
                Text("确定要退出登录吗？")
            }
            // 删除账户确认 Sheet
            .sheet(isPresented: $showDeleteSheet) {
                deleteAccountSheet
            }
            // 删除成功提示
            .alert("账户已删除", isPresented: $showDeleteSuccess) {
                Button("确定", role: .cancel) { }
            } message: {
                Text("您的账户和所有相关数据已被永久删除。")
            }
        }
    }

    // MARK: - 用户信息视图
    private var userInfoView: some View {
        HStack(spacing: 16) {
            // 头像
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 70)

                Text(avatarText)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            // 用户信息
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(currentUser?.email ?? "未知邮箱")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                // 用户ID（简短显示）
                if let userId = currentUser?.id.uuidString.prefix(8) {
                    Text("ID: \(userId)...")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }

    // MARK: - 删除账户确认 Sheet
    private var deleteAccountSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // 警告图标
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)
                    .padding(.top, 20)

                // 标题
                Text("删除账户")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.red)

                // 警告说明
                VStack(alignment: .leading, spacing: 12) {
                    Text("此操作不可撤销！")
                        .font(.headline)
                        .foregroundColor(.red)

                    Text("删除账户将永久删除以下数据：")
                        .font(.subheadline)

                    VStack(alignment: .leading, spacing: 8) {
                        Label("您的个人资料", systemImage: "person.fill")
                        Label("所有领地数据", systemImage: "map.fill")
                        Label("所有发现的POI", systemImage: "mappin.circle.fill")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)

                // 确认输入区域
                VStack(alignment: .leading, spacing: 8) {
                    Text("请输入「\(deleteKeyword)」以确认：")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    TextField("输入\(deleteKeyword)", text: $deleteConfirmText)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }

                Spacer()

                // 按钮区域
                VStack(spacing: 12) {
                    // 确认删除按钮
                    Button {
                        print("🔴 [个人页] 用户确认删除账户")
                        performDeleteAccount()
                    } label: {
                        HStack {
                            if isDeleting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .padding(.trailing, 8)
                            }
                            Text(isDeleting ? "正在删除..." : "永久删除账户")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canDelete && !isDeleting ? Color.red : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!canDelete || isDeleting)

                    // 取消按钮
                    Button("取消") {
                        print("🔴 [个人页] 用户取消删除账户")
                        showDeleteSheet = false
                    }
                    .foregroundColor(.blue)
                    .disabled(isDeleting)
                }
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        showDeleteSheet = false
                    }
                    .disabled(isDeleting)
                }
            }
            .interactiveDismissDisabled(isDeleting)
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - 执行删除账户
    private func performDeleteAccount() {
        print("🔴 [个人页] 开始执行删除账户...")
        isDeleting = true

        Task {
            print("🔴 [个人页] 调用 AuthManager.deleteAccount()...")
            let success = await authManager.deleteAccount()

            await MainActor.run {
                isDeleting = false

                if success {
                    print("✅ [个人页] 账户删除成功!")
                    showDeleteSheet = false
                    showDeleteSuccess = true
                } else {
                    print("❌ [个人页] 账户删除失败: \(authManager.errorMessage ?? "未知错误")")
                }
            }
        }
    }

    // MARK: - Computed Properties

    /// 显示名称
    private var displayName: String {
        if let email = currentUser?.email {
            // 取邮箱@前面的部分作为用户名
            return String(email.split(separator: "@").first ?? "用户")
        }
        return "用户"
    }

    /// 头像文字（取用户名首字符）
    private var avatarText: String {
        let name = displayName
        if let first = name.first {
            return String(first).uppercased()
        }
        return "U"
    }
}

#Preview {
    ProfileTabView()
}
