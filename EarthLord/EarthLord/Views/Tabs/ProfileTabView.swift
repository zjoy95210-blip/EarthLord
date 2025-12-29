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

    /// 是否显示退出确认弹窗
    @State private var showLogoutAlert = false

    /// 当前用户
    private var currentUser: User? {
        authManager.currentUser
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
            }
            .navigationTitle("个人")
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
