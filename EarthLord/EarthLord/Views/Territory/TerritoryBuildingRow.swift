//
//  TerritoryBuildingRow.swift
//  EarthLord
//
//  领地建筑行组件（带操作菜单和倒计时）
//

import SwiftUI
import Combine

struct TerritoryBuildingRow: View {

    // MARK: - Properties

    let building: PlayerBuilding
    let template: BuildingTemplate?
    let onUpgrade: () -> Void
    let onDemolish: () -> Void

    /// 当前时间（用于计算倒计时）
    @State private var currentTime = Date()

    /// 定时器
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // MARK: - Computed Properties

    /// 剩余建造/升级时间（秒）
    private var remainingSeconds: Int {
        guard let startedAt = building.startedAt,
              building.status == .constructing || building.status == .upgrading else {
            return 0
        }

        let buildTime = template?.buildTime ?? 0
        let elapsed = currentTime.timeIntervalSince(startedAt)
        let remaining = Double(buildTime) - elapsed

        return max(0, Int(remaining))
    }

    /// 格式化剩余时间
    private var formattedRemainingTime: String {
        let seconds = remainingSeconds
        if seconds >= 3600 {
            let hours = seconds / 3600
            let minutes = (seconds % 3600) / 60
            return "\(hours)小时\(minutes)分"
        } else if seconds >= 60 {
            let minutes = seconds / 60
            let secs = seconds % 60
            return "\(minutes)分\(secs)秒"
        } else {
            return "\(seconds)秒"
        }
    }

    /// 进度百分比
    private var progress: Double {
        guard let startedAt = building.startedAt,
              let buildTime = template?.buildTime,
              buildTime > 0,
              building.status == .constructing || building.status == .upgrading else {
            return 1.0
        }

        let elapsed = currentTime.timeIntervalSince(startedAt)
        return min(1.0, elapsed / Double(buildTime))
    }

    /// 分类颜色
    private var categoryColor: Color {
        if let template = template {
            return Color(hex: template.category.colorHex)
        }
        return ApocalypseTheme.primary
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            // 建筑图标
            buildingIcon

            // 建筑信息
            VStack(alignment: .leading, spacing: 4) {
                // 名称和等级
                HStack {
                    Text(template?.name ?? "未知建筑")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text("Lv.\(building.level)")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(4)
                }

                // 状态或描述
                if building.status == .constructing || building.status == .upgrading {
                    // 进度条
                    VStack(alignment: .leading, spacing: 2) {
                        ProgressView(value: progress)
                            .progressViewStyle(LinearProgressViewStyle(tint: categoryColor))

                        Text("剩余 \(formattedRemainingTime)")
                            .font(.caption2)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                } else {
                    Text(template?.description ?? "")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // 操作菜单
            if building.status == .active {
                Menu {
                    // 升级按钮
                    if let template = template,
                       building.level < template.maxLevel {
                        Button {
                            onUpgrade()
                        } label: {
                            Label("升级", systemImage: "arrow.up.circle")
                        }
                    }

                    // 拆除按钮
                    Button(role: .destructive) {
                        onDemolish()
                    } label: {
                        Label("拆除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            } else {
                // 状态图标
                Image(systemName: building.status.iconName)
                    .font(.system(size: 20))
                    .foregroundColor(categoryColor)
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }

    // MARK: - 建筑图标
    private var buildingIcon: some View {
        ZStack {
            Circle()
                .fill(categoryColor.opacity(0.2))
                .frame(width: 44, height: 44)

            if building.status == .constructing || building.status == .upgrading {
                // 建造/升级中动画
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(categoryColor, lineWidth: 3)
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))
            }

            Image(systemName: template?.iconName ?? "building.2.fill")
                .font(.system(size: 18))
                .foregroundColor(categoryColor)
        }
    }
}

// MARK: - Preview
#Preview {
    let sampleTemplate = BuildingTemplate(
        id: "campfire",
        name: "篝火",
        description: "提供基础照明和温暖",
        category: .survival,
        tier: 1,
        maxPerTerritory: 2,
        buildTime: 120,
        requiredMaterials: [],
        maxLevel: 3,
        iconName: "flame.fill",
        effects: nil
    )

    VStack(spacing: 12) {
        TerritoryBuildingRow(
            building: PlayerBuilding(
                id: UUID(),
                userId: UUID(),
                territoryId: UUID(),
                templateId: "campfire",
                level: 2,
                status: .active,
                startedAt: nil,
                completedAt: Date(),
                createdAt: Date(),
                locationLat: 31.23,
                locationLon: 121.47
            ),
            template: sampleTemplate,
            onUpgrade: {},
            onDemolish: {}
        )

        TerritoryBuildingRow(
            building: PlayerBuilding(
                id: UUID(),
                userId: UUID(),
                territoryId: UUID(),
                templateId: "campfire",
                level: 1,
                status: .constructing,
                startedAt: Date().addingTimeInterval(-60),
                completedAt: nil,
                createdAt: Date(),
                locationLat: 31.23,
                locationLon: 121.47
            ),
            template: sampleTemplate,
            onUpgrade: {},
            onDemolish: {}
        )
    }
    .padding()
    .background(ApocalypseTheme.background)
}
