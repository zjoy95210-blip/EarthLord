//
//  TerritoryLogger.swift
//  EarthLord
//
//  圈地功能日志管理器 - 记录圈地模块的调试日志
//

import Foundation
import SwiftUI
import Combine

// MARK: - 日志类型
enum LogType: String {
    case info = "INFO"
    case success = "SUCCESS"
    case warning = "WARNING"
    case error = "ERROR"

    /// 日志颜色
    var color: Color {
        switch self {
        case .info:
            return .gray
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}

// MARK: - 日志条目
struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let type: LogType

    /// 格式化显示文本（用于界面显示）
    var displayText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return "[\(formatter.string(from: timestamp))] [\(type.rawValue)] \(message)"
    }

    /// 格式化导出文本（用于导出）
    var exportText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return "[\(formatter.string(from: timestamp))] [\(type.rawValue)] \(message)"
    }
}

// MARK: - 日志管理器
@MainActor
final class TerritoryLogger: ObservableObject {

    // MARK: - Singleton
    static let shared = TerritoryLogger()

    // MARK: - Published Properties

    /// 日志数组
    @Published var logs: [LogEntry] = []

    /// 格式化的日志文本（用于显示）
    @Published var logText: String = ""

    // MARK: - Private Properties

    /// 最大日志条数（防止内存溢出）
    private let maxLogCount = 200

    // MARK: - Initialization

    private init() {
        // 添加初始日志
        log("圈地测试日志模块已启动", type: .info)
    }

    // MARK: - Public Methods

    /// 添加日志
    /// - Parameters:
    ///   - message: 日志消息
    ///   - type: 日志类型
    func log(_ message: String, type: LogType = .info) {
        let entry = LogEntry(timestamp: Date(), message: message, type: type)

        // 添加到数组
        logs.append(entry)

        // 限制最大条数
        if logs.count > maxLogCount {
            logs.removeFirst(logs.count - maxLogCount)
        }

        // 更新格式化文本
        updateLogText()

        // 同时输出到控制台（方便 Xcode 调试）
        print("📝 [圈地日志] \(entry.displayText)")
    }

    /// 清空所有日志
    func clear() {
        logs.removeAll()
        logText = ""
        log("日志已清空", type: .info)
    }

    /// 导出日志为文本
    /// - Returns: 格式化的日志文本
    func export() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        var exportString = """
        === 圈地功能测试日志 ===
        导出时间: \(formatter.string(from: Date()))
        日志条数: \(logs.count)

        """

        for entry in logs {
            exportString += entry.exportText + "\n"
        }

        return exportString
    }

    // MARK: - Private Methods

    /// 更新格式化日志文本
    private func updateLogText() {
        logText = logs.map { $0.displayText }.joined(separator: "\n")
    }
}
