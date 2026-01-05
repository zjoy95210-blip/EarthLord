//
//  TerritoryTestView.swift
//  EarthLord
//
//  圈地功能测试界面 - 显示圈地模块调试日志
//

import SwiftUI

struct TerritoryTestView: View {

    // MARK: - Properties

    /// 定位管理器（监听追踪状态）
    @EnvironmentObject var locationManager: LocationManager

    /// 日志管理器
    @ObservedObject var logger = TerritoryLogger.shared

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 状态指示器
            statusIndicator
                .padding()

            Divider()

            // 日志滚动区域
            logScrollView

            Divider()

            // 底部按钮栏
            buttonBar
                .padding()
        }
        .navigationTitle("圈地测试")
        .navigationBarTitleDisplayMode(.inline)
        .background(ApocalypseTheme.background)
    }

    // MARK: - 状态指示器

    private var statusIndicator: some View {
        HStack(spacing: 12) {
            // 状态点
            Circle()
                .fill(locationManager.isTracking ? Color.green : Color.gray)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(locationManager.isTracking ? Color.green.opacity(0.3) : Color.clear, lineWidth: 4)
                )
                .animation(.easeInOut(duration: 0.3), value: locationManager.isTracking)

            // 状态文字
            Text(locationManager.isTracking ? "追踪中" : "未追踪")
                .font(.headline)
                .foregroundColor(locationManager.isTracking ? .green : ApocalypseTheme.textSecondary)

            Spacer()

            // 路径点数
            if locationManager.isTracking || locationManager.pathPointCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle")
                        .foregroundColor(ApocalypseTheme.primary)
                    Text("\(locationManager.pathPointCount) 点")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }

            // 闭环状态
            if locationManager.isPathClosed {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                    Text("已闭环")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 日志滚动区域

    private var logScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if logger.logs.isEmpty {
                        // 空状态
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 40))
                                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))

                            Text("暂无日志")
                                .font(.subheadline)
                                .foregroundColor(ApocalypseTheme.textSecondary)

                            Text("开始圈地追踪后日志将在此显示")
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else {
                        // 日志列表
                        ForEach(logger.logs) { entry in
                            logEntryRow(entry)
                        }

                        // 底部锚点（用于自动滚动）
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                }
                .padding()
            }
            .background(ApocalypseTheme.background)
            .onChange(of: logger.logText) { _, _ in
                // 日志更新时自动滚动到底部
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    /// 单条日志行
    private func logEntryRow(_ entry: LogEntry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            // 时间戳
            Text(formatTime(entry.timestamp))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(ApocalypseTheme.textSecondary)

            // 类型标签
            Text("[\(entry.type.rawValue)]")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(entry.type.color)

            // 消息内容
            Text(entry.message)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()
        }
        .padding(.vertical, 4)
    }

    /// 格式化时间
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    // MARK: - 底部按钮栏

    private var buttonBar: some View {
        HStack(spacing: 16) {
            // 清空按钮
            Button {
                logger.clear()
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("清空日志")
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.red.opacity(0.8))
                .cornerRadius(10)
            }

            // 导出按钮
            ShareLink(item: logger.export()) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("导出日志")
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(ApocalypseTheme.primary)
                .cornerRadius(10)
            }
        }
    }
}

#Preview {
    NavigationStack {
        TerritoryTestView()
            .environmentObject(LocationManager.shared)
    }
}
