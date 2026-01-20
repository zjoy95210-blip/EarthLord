//
//  POIDetailView.swift
//  EarthLord
//
//  POI 详情页面
//  显示兴趣点的详细信息，支持搜寻和标记操作
//

import SwiftUI

struct POIDetailView: View {

    // MARK: - Properties

    /// POI 数据
    let poi: ExplorationPOI

    /// 环境变量用于返回
    @Environment(\.dismiss) private var dismiss

    /// 是否显示探索结果弹窗
    @State private var showExplorationResult: Bool = false

    /// 是否正在搜寻
    @State private var isSearching: Bool = false

    /// 本地状态：是否已标记发现
    @State private var isMarkedDiscovered: Bool = false

    /// 本地状态：是否已标记无物资
    @State private var isMarkedEmpty: Bool = false

    // MARK: - 假数据

    /// 距离（假数据）
    private let mockDistance: Int = 350

    /// 危险等级（假数据）
    private let mockDangerLevel: DangerLevel = .low

    /// 数据来源（假数据）
    private let mockSource: String = "地图数据"

    // MARK: - 计算属性

    /// POI 类型颜色
    private var typeColor: Color {
        switch poi.type {
        case "hospital":
            return poi.name.contains("药") ? Color(hex: "9C27B0") : Color(hex: "F44336")
        case "supermarket":
            return Color(hex: "4CAF50")
        case "factory":
            return Color(hex: "607D8B")
        case "gas_station":
            return Color(hex: "FF9800")
        default:
            return ApocalypseTheme.primary
        }
    }

    /// POI 类型图标
    private var typeIcon: String {
        switch poi.type {
        case "hospital":
            return poi.name.contains("药") ? "pills.fill" : "cross.case.fill"
        case "supermarket":
            return "cart.fill"
        case "factory":
            return "building.2.fill"
        case "gas_station":
            return "fuelpump.fill"
        default:
            return "mappin.circle.fill"
        }
    }

    /// 是否可以搜寻
    private var canSearch: Bool {
        return poi.resourceStatus == .hasResources && !isMarkedEmpty
    }

    /// 物资状态文字
    private var resourceStatusText: String {
        if isMarkedEmpty {
            return "已标记无物资"
        }
        switch poi.resourceStatus {
        case .hasResources:
            return "有物资"
        case .empty:
            return "已清空"
        case .unknown:
            return "未知"
        }
    }

    /// 物资状态颜色
    private var resourceStatusColor: Color {
        if isMarkedEmpty || poi.resourceStatus == .empty {
            return ApocalypseTheme.textMuted
        }
        switch poi.resourceStatus {
        case .hasResources:
            return ApocalypseTheme.success
        case .unknown:
            return ApocalypseTheme.warning
        default:
            return ApocalypseTheme.textMuted
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景色
            ApocalypseTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // 顶部大图区域
                    heroSection

                    // 信息区域
                    infoSection
                        .padding(.horizontal, 16)
                        .padding(.top, 20)

                    // 操作按钮区域
                    actionSection
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                        .padding(.bottom, 40)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    // 分享功能占位
                    print("📍 [POI详情] 分享 POI: \(poi.name)")
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }
            }
        }
        .onAppear {
            // 初始化本地状态
            isMarkedDiscovered = poi.discoveryStatus == .discovered
            isMarkedEmpty = poi.resourceStatus == .empty
        }
        .sheet(isPresented: $showExplorationResult, onDismiss: {
            // 搜寻后标记为无物资
            isMarkedEmpty = true
        }) {
            // TODO: 替换为真实的探索结果数据
            ExplorationResultView(explorationResult: ExplorationResult(
                sessionId: UUID(),
                distance: 500,
                duration: 300,
                rewardTier: .bronze,
                rewardedItems: [],
                startCoordinate: nil,
                endCoordinate: nil,
                totalDistance: 500,
                totalDuration: 300
            ))
        }
    }

    // MARK: - 顶部大图区域

    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            // 渐变背景
            LinearGradient(
                colors: [
                    typeColor,
                    typeColor.opacity(0.7),
                    ApocalypseTheme.background
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 280)

            // 大图标
            VStack {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 120, height: 120)

                    Image(systemName: typeIcon)
                        .font(.system(size: 56))
                        .foregroundColor(.white)
                }

                Spacer()
            }
            .frame(height: 200)
            .padding(.top, 40)

            // 底部遮罩和文字
            VStack(spacing: 6) {
                // POI 名称
                Text(poi.displayName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                // POI 类型
                HStack(spacing: 6) {
                    Image(systemName: typeIcon)
                        .font(.system(size: 14))

                    Text(poi.typeDisplayName)
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0),
                        Color.black.opacity(0.6)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    // MARK: - 信息区域

    private var infoSection: some View {
        VStack(spacing: 12) {
            // 距离
            infoCard(
                icon: "location.fill",
                iconColor: ApocalypseTheme.info,
                title: "距离",
                value: "\(mockDistance)米",
                valueColor: ApocalypseTheme.textPrimary
            )

            // 物资状态
            infoCard(
                icon: poi.resourceStatus == .hasResources ? "shippingbox.fill" : "shippingbox",
                iconColor: resourceStatusColor,
                title: "物资状态",
                value: resourceStatusText,
                valueColor: resourceStatusColor
            )

            // 危险等级
            infoCard(
                icon: mockDangerLevel.icon,
                iconColor: mockDangerLevel.color,
                title: "危险等级",
                value: mockDangerLevel.displayName,
                valueColor: mockDangerLevel.color
            )

            // 数据来源
            infoCard(
                icon: "info.circle.fill",
                iconColor: ApocalypseTheme.textSecondary,
                title: "来源",
                value: mockSource,
                valueColor: ApocalypseTheme.textSecondary
            )

            // 描述（如有）
            if let description = poi.poiDescription {
                VStack(alignment: .leading, spacing: 8) {
                    Text("描述")
                        .font(.system(size: 13))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(ApocalypseTheme.cardBackground)
                )
            }
        }
    }

    /// 信息卡片
    private func infoCard(
        icon: String,
        iconColor: Color,
        title: String,
        value: String,
        valueColor: Color
    ) -> some View {
        HStack(spacing: 14) {
            // 图标
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
            }

            // 标题
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()

            // 值
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(valueColor)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - 操作按钮区域

    private var actionSection: some View {
        VStack(spacing: 14) {
            // 主按钮：搜寻此POI
            Button {
                performSearch()
            } label: {
                HStack(spacing: 10) {
                    if isSearching {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)

                        Text("搜寻中...")
                            .font(.system(size: 17, weight: .semibold))
                    } else {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18, weight: .semibold))

                        Text("搜寻此POI")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Group {
                        if canSearch {
                            LinearGradient(
                                colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        } else {
                            LinearGradient(
                                colors: [ApocalypseTheme.textMuted, ApocalypseTheme.textMuted],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        }
                    }
                )
                .cornerRadius(14)
                .shadow(
                    color: canSearch ? ApocalypseTheme.primary.opacity(0.4) : Color.clear,
                    radius: 8, x: 0, y: 4
                )
            }
            .disabled(!canSearch || isSearching)

            // 不可搜寻提示
            if !canSearch && !isSearching {
                Text("该地点已无物资可搜寻")
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            // 小按钮行
            HStack(spacing: 12) {
                // 标记已发现
                secondaryButton(
                    icon: isMarkedDiscovered ? "checkmark.circle.fill" : "eye.fill",
                    text: isMarkedDiscovered ? "已标记发现" : "标记已发现",
                    isActive: isMarkedDiscovered
                ) {
                    handleMarkDiscovered()
                }

                // 标记无物资
                secondaryButton(
                    icon: isMarkedEmpty ? "checkmark.circle.fill" : "xmark.circle",
                    text: isMarkedEmpty ? "已标记无物资" : "标记无物资",
                    isActive: isMarkedEmpty
                ) {
                    handleMarkEmpty()
                }
            }
        }
    }

    /// 次要按钮
    private func secondaryButton(
        icon: String,
        text: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))

                Text(text)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(isActive ? ApocalypseTheme.success : ApocalypseTheme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isActive ? ApocalypseTheme.success.opacity(0.15) : ApocalypseTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isActive ? ApocalypseTheme.success.opacity(0.3) : ApocalypseTheme.textMuted.opacity(0.3),
                        lineWidth: 1
                    )
            )
        }
    }

    // MARK: - Actions

    /// 执行搜寻
    private func performSearch() {
        guard canSearch else { return }

        isSearching = true
        print("🔍 [POI详情] 开始搜寻: \(poi.name)")

        // 模拟搜寻过程（2秒）
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isSearching = false
            withAnimation {
                showExplorationResult = true
            }
            print("✅ [POI详情] 搜寻完成")
        }
    }

    /// 标记已发现
    private func handleMarkDiscovered() {
        isMarkedDiscovered.toggle()
        print("📍 [POI详情] 标记发现: \(isMarkedDiscovered)")
    }

    /// 标记无物资
    private func handleMarkEmpty() {
        isMarkedEmpty.toggle()
        print("📍 [POI详情] 标记无物资: \(isMarkedEmpty)")
    }
}

// MARK: - 危险等级枚举

enum DangerLevel: String, CaseIterable, Codable, Sendable {
    case safe = "safe"          // 安全
    case low = "low"            // 低危 (1)
    case medium = "medium"      // 中低危 (2)
    case moderate = "moderate"  // 中危 (3)
    case high = "high"          // 高危 (4)
    case extreme = "extreme"    // 极危 (5)

    var displayName: String {
        switch self {
        case .safe: return "安全"
        case .low: return "低危"
        case .medium: return "中低危"
        case .moderate: return "中危"
        case .high: return "高危"
        case .extreme: return "极危"
        }
    }

    var icon: String {
        switch self {
        case .safe: return "shield.checkered"
        case .low: return "exclamationmark.shield"
        case .medium: return "exclamationmark.shield.fill"
        case .moderate: return "exclamationmark.triangle"
        case .high: return "exclamationmark.triangle.fill"
        case .extreme: return "exclamationmark.octagon.fill"
        }
    }

    var color: Color {
        switch self {
        case .safe: return Color(hex: "4CAF50")      // 绿色
        case .low: return Color(hex: "8BC34A")       // 浅绿
        case .medium: return Color(hex: "CDDC39")    // 黄绿
        case .moderate: return Color(hex: "FFC107")  // 黄色
        case .high: return Color(hex: "FF9800")      // 橙色
        case .extreme: return Color(hex: "F44336")   // 红色
        }
    }

    var colorHex: String {
        switch self {
        case .safe: return "4CAF50"      // 绿色
        case .low: return "8BC34A"       // 浅绿
        case .medium: return "CDDC39"    // 黄绿
        case .moderate: return "FFC107"  // 黄色
        case .high: return "FF9800"      // 橙色
        case .extreme: return "F44336"   // 红色
        }
    }

    /// 整数值（用于 API 请求）
    var intValue: Int {
        switch self {
        case .safe: return 0
        case .low: return 1
        case .medium: return 2
        case .moderate: return 3
        case .high: return 4
        case .extreme: return 5
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        POIDetailView(poi: MockExplorationData.explorationPOIs[0])
    }
}
