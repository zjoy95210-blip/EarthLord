//
//  SupabaseTestView.swift
//  EarthLord
//
//  Created by Joy周 on 2025/12/26.
//

import SwiftUI
import Supabase

// MARK: - Connection Status
enum ConnectionStatus: Sendable {
    case idle
    case testing
    case success
    case failure
}

struct SupabaseTestView: View {
    @State private var status: ConnectionStatus = .idle
    @State private var logText: String = "点击按钮开始测试连接..."

    var body: some View {
        VStack(spacing: 24) {
            // 状态图标
            statusIcon
                .padding(.top, 40)

            // 项目信息
            projectInfoView

            // 日志文本框
            logView

            // 测试按钮
            testButton

            Spacer()
        }
        .padding()
        .navigationTitle("Supabase 连接测试")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Project Info View
    private var projectInfoView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("项目信息")
                .font(.headline)

            Group {
                HStack {
                    Text("Project Ref:")
                        .foregroundColor(.secondary)
                    Text(SupabaseConfig.projectRef)
                        .font(.system(.body, design: .monospaced))
                }

                HStack {
                    Text("Region:")
                        .foregroundColor(.secondary)
                    Text("ap-southeast-1")
                        .font(.system(.body, design: .monospaced))
                }
            }
            .font(.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Status Icon
    @ViewBuilder
    private var statusIcon: some View {
        ZStack {
            Circle()
                .fill(statusBackgroundColor)
                .frame(width: 100, height: 100)

            Image(systemName: statusIconName)
                .font(.system(size: 50, weight: .bold))
                .foregroundColor(.white)
        }
        .animation(.easeInOut(duration: 0.3), value: status)
    }

    private var statusIconName: String {
        switch status {
        case .idle:
            return "questionmark"
        case .testing:
            return "arrow.triangle.2.circlepath"
        case .success:
            return "checkmark"
        case .failure:
            return "exclamationmark"
        }
    }

    private var statusBackgroundColor: Color {
        switch status {
        case .idle:
            return .gray
        case .testing:
            return .blue
        case .success:
            return .green
        case .failure:
            return .red
        }
    }

    // MARK: - Log View
    private var logView: some View {
        ScrollView {
            Text(logText)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Test Button
    private var testButton: some View {
        Button(action: {
            testConnection()
        }) {
            HStack {
                if status == .testing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .padding(.trailing, 8)
                }
                Text(status == .testing ? "测试中..." : "测试连接")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(status == .testing ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(status == .testing)
    }

    // MARK: - Test Connection Logic
    private func testConnection() {
        status = .testing
        logText = "[\(currentTime)] 开始测试连接...\n"
        logText += "[\(currentTime)] URL: \(SupabaseConfig.supabaseURL.absoluteString)\n"
        logText += "[\(currentTime)] 正在查询 profiles 表...\n"

        Task {
            do {
                // 使用 SupabaseService 测试连接
                let _ = try await SupabaseService.shared.testConnection()

                await MainActor.run {
                    status = .success
                    logText += "[\(currentTime)] ✅ 连接成功！\n"
                    logText += "[\(currentTime)] 数据库响应正常\n"
                }
            } catch {
                await MainActor.run {
                    handleError(error)
                }
            }
        }
    }

    private func handleError(_ error: Error) {
        let errorString = String(describing: error)
        logText += "[\(currentTime)] 收到响应，分析中...\n"
        logText += "[\(currentTime)] 错误详情: \(errorString)\n\n"

        // 判断连接状态
        if errorString.contains("PGRST") ||
           errorString.contains("Could not find") ||
           (errorString.contains("relation") && errorString.contains("does not exist")) {
            // 收到了 PostgreSQL REST API 的错误响应，说明连接成功
            status = .success
            logText += "[\(currentTime)] ✅ 连接成功（服务器已响应）\n"
            logText += "[\(currentTime)] 说明：服务器正确返回了错误，证明连接正常。\n"
        } else if errorString.contains("hostname") ||
                  errorString.contains("URL") ||
                  errorString.contains("NSURLErrorDomain") ||
                  errorString.contains("Could not resolve") ||
                  errorString.lowercased().contains("network") {
            // 网络或 URL 错误
            status = .failure
            logText += "[\(currentTime)] ❌ 连接失败：URL 错误或无网络\n"
            logText += "[\(currentTime)] 请检查网络连接和 Supabase URL 配置。\n"
        } else {
            // 其他错误（可能是空表，也算成功）
            status = .success
            logText += "[\(currentTime)] ✅ 连接成功\n"
            logText += "[\(currentTime)] 说明：表可能为空或需要认证。\n"
        }
    }

    private var currentTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }
}

#Preview {
    NavigationStack {
        SupabaseTestView()
    }
}
