//
//  ExplorationResultView.swift
//  EarthLord
//
//  探索结果页面
//  探索结束后显示收获的弹窗，包含统计数据和获得物品
//

import SwiftUI

struct ExplorationResultView: View {

    // MARK: - Properties

    /// 探索结果数据（成功时有值）
    let result: ExplorationResult?

    /// 错误信息（失败时有值）
    let errorMessage: String?

    /// 重试回调
    var onRetry: (() -> Void)?

    /// 环境变量用于关闭页面
    @Environment(\.dismiss) private var dismiss

    /// 动画状态
    @State private var showContent: Bool = false
    @State private var showStats: Bool = false
    @State private var showRewards: Bool = false
    @State private var showButton: Bool = false

    /// 统计数字动画值
    @State private var animatedDistance: Double = 0
    @State private var animatedArea: Double = 0
    @State private var animatedDuration: Double = 0

    /// 已显示的奖励物品索引
    @State private var visibleRewardIndices: Set<Int> = []

    /// 对勾图标弹跳状态
    @State private var checkmarkBounced: Set<Int> = []

    // MARK: - 便捷初始化器

    /// 成功结果初始化
    init(result: ExplorationResult) {
        self.result = result
        self.errorMessage = nil
        self.onRetry = nil
    }

    /// 错误状态初始化
    init(errorMessage: String, onRetry: @escaping () -> Void) {
        self.result = nil
        self.errorMessage = errorMessage
        self.onRetry = onRetry
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景
            ApocalypseTheme.background
                .ignoresSafeArea()

            // 根据状态显示不同内容
            if let errorMessage = errorMessage {
                // 错误状态
                errorStateView(message: errorMessage)
            } else if let result = result {
                // 成功状态
                successStateView(result: result)
            }
        }
        .onAppear {
            if result != nil {
                startAnimations()
            } else {
                // 错误状态直接显示
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    showContent = true
                    showButton = true
                }
            }
        }
    }

    // MARK: - 成功状态视图

    private func successStateView(result: ExplorationResult) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // 成就标题
                achievementHeader
                    .opacity(showContent ? 1 : 0)
                    .scaleEffect(showContent ? 1 : 0.8)

                // 统计数据卡片
                statisticsCard
                    .opacity(showStats ? 1 : 0)
                    .offset(y: showStats ? 0 : 20)

                // 奖励物品卡片
                rewardsCard
                    .opacity(showRewards ? 1 : 0)
                    .offset(y: showRewards ? 0 : 20)

                // 确认按钮
                confirmButton
                    .opacity(showButton ? 1 : 0)
                    .scaleEffect(showButton ? 1 : 0.9)

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 40)
        }
    }

    // MARK: - 错误状态视图

    private func errorStateView(message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()

            // 错误图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.danger.opacity(0.15))
                    .frame(width: 100, height: 100)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.danger)
            }
            .opacity(showContent ? 1 : 0)
            .scaleEffect(showContent ? 1 : 0.5)

            // 错误标题
            Text("探索失败")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .opacity(showContent ? 1 : 0)

            // 错误信息
            Text(message)
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .opacity(showContent ? 1 : 0)

            Spacer()

            // 按钮区域
            VStack(spacing: 12) {
                // 重试按钮
                if let onRetry = onRetry {
                    Button {
                        onRetry()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .semibold))

                            Text("重新探索")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(ApocalypseTheme.primary)
                        )
                    }
                }

                // 关闭按钮
                Button {
                    dismiss()
                } label: {
                    Text("返回")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(ApocalypseTheme.textMuted.opacity(0.5), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
            .opacity(showButton ? 1 : 0)
            .offset(y: showButton ? 0 : 20)
        }
    }

    // MARK: - 动画控制

    private func startAnimations() {
        // 依次显示各个部分，营造仪式感
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            showContent = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showStats = true
            }
            // 开始统计数字跳动动画
            startNumberCountingAnimation()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showRewards = true
            }
            // 开始奖励物品依次出现动画
            startRewardItemsAnimation()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showButton = true
            }
        }
    }

    /// 统计数字跳动动画
    private func startNumberCountingAnimation() {
        guard let result = result else { return }

        // 距离数字动画（0.6秒完成）
        withAnimation(.easeOut(duration: 0.6)) {
            animatedDistance = result.sessionDistance
        }

        // 面积数字动画（0.7秒完成）
        withAnimation(.easeOut(duration: 0.7)) {
            animatedArea = result.sessionArea
        }

        // 时长数字动画（0.5秒完成）
        withAnimation(.easeOut(duration: 0.5)) {
            animatedDuration = Double(result.sessionDuration)
        }
    }

    /// 奖励物品依次出现动画
    private func startRewardItemsAnimation() {
        guard let result = result else { return }

        for index in result.obtainedItems.indices {
            // 错开 0.2 秒依次出现
            let delay = Double(index) * 0.2
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    _ = visibleRewardIndices.insert(index)
                }

                // 对勾弹跳效果（在物品出现后 0.15 秒）
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        _ = checkmarkBounced.insert(index)
                    }
                }
            }
        }
    }

    // MARK: - 成就标题

    private var achievementHeader: some View {
        VStack(spacing: 16) {
            // 大图标（带光晕效果）
            ZStack {
                // 外圈光晕
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                ApocalypseTheme.primary.opacity(0.3),
                                ApocalypseTheme.primary.opacity(0)
                            ],
                            center: .center,
                            startRadius: 40,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)

                // 内圈
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.15))
                    .frame(width: 100, height: 100)

                // 图标
                Image(systemName: "map.fill")
                    .font(.system(size: 44))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            // 大文字
            Text("探索完成！")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 副标题
            Text("你又征服了一片未知领域")
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .padding(.bottom, 8)
    }

    // MARK: - 统计数据卡片

    private var statisticsCard: some View {
        VStack(spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 16))
                    .foregroundColor(ApocalypseTheme.info)

                Text("探索统计")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()
            }

            // 分隔线
            Rectangle()
                .fill(ApocalypseTheme.textMuted.opacity(0.2))
                .frame(height: 1)

            // 行走距离
            statisticRow(
                icon: "figure.walk",
                iconColor: Color(hex: "4CAF50"),
                title: "行走距离",
                sessionValue: formatDistance(animatedDistance),
                totalValue: formatDistance(result?.totalDistance ?? 0),
                rank: result?.distanceRank ?? 0
            )

            // 探索面积
            statisticRow(
                icon: "square.dashed",
                iconColor: Color(hex: "2196F3"),
                title: "探索面积",
                sessionValue: formatArea(animatedArea),
                totalValue: formatArea(result?.totalArea ?? 0),
                rank: result?.areaRank ?? 0
            )

            // 探索时长
            HStack {
                // 图标
                ZStack {
                    Circle()
                        .fill(Color(hex: "FF9800").opacity(0.15))
                        .frame(width: 36, height: 36)

                    Image(systemName: "clock.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "FF9800"))
                }

                // 标题
                Text("探索时长")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()

                // 时长值（使用动画值）
                Text(formatDuration(animatedDuration))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .contentTransition(.numericText())
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    /// 统计行
    private func statisticRow(
        icon: String,
        iconColor: Color,
        title: String,
        sessionValue: String,
        totalValue: String,
        rank: Int
    ) -> some View {
        VStack(spacing: 10) {
            HStack {
                // 图标
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 36, height: 36)

                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(iconColor)
                }

                // 标题
                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()

                // 排名
                HStack(spacing: 2) {
                    Text("#")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.success)

                    Text("\(rank)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(ApocalypseTheme.success)
                }
            }

            // 数值行
            HStack {
                // 本次
                VStack(alignment: .leading, spacing: 2) {
                    Text("本次")
                        .font(.system(size: 11))
                        .foregroundColor(ApocalypseTheme.textMuted)

                    Text(sessionValue)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.primary)
                }

                Spacer()

                // 分隔线
                Rectangle()
                    .fill(ApocalypseTheme.textMuted.opacity(0.3))
                    .frame(width: 1, height: 30)

                Spacer()

                // 累计
                VStack(alignment: .trailing, spacing: 2) {
                    Text("累计")
                        .font(.system(size: 11))
                        .foregroundColor(ApocalypseTheme.textMuted)

                    Text(totalValue)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }
            }
            .padding(.leading, 44)
        }
    }

    /// 格式化距离
    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.2f km", meters / 1000)
        } else {
            return String(format: "%.0f m", meters)
        }
    }

    /// 格式化面积
    private func formatArea(_ sqMeters: Double) -> String {
        if sqMeters >= 10000 {
            return String(format: "%.2f 万m²", sqMeters / 10000)
        } else {
            return String(format: "%.0f m²", sqMeters)
        }
    }

    /// 格式化时长
    private func formatDuration(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        if minutes > 0 {
            return "\(minutes)分\(secs)秒"
        } else {
            return "\(secs)秒"
        }
    }

    // MARK: - 奖励物品卡片

    private var rewardsCard: some View {
        VStack(spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "gift.fill")
                    .font(.system(size: 16))
                    .foregroundColor(ApocalypseTheme.warning)

                Text("获得物品")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                // 物品数量
                Text("\(result?.obtainedItems.count ?? 0) 种")
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 分隔线
            Rectangle()
                .fill(ApocalypseTheme.textMuted.opacity(0.2))
                .frame(height: 1)

            // 物品列表
            VStack(spacing: 12) {
                ForEach(Array((result?.obtainedItems ?? []).enumerated()), id: \.element.id) { index, item in
                    rewardItemRow(item: item, index: index)
                        .opacity(visibleRewardIndices.contains(index) ? 1 : 0)
                        .offset(x: visibleRewardIndices.contains(index) ? 0 : -30)
                }
            }

            // 底部提示
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.success)

                Text("已添加到背包")
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.success)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    /// 奖励物品行
    private func rewardItemRow(item: ObtainedItem, index: Int) -> some View {
        HStack(spacing: 12) {
            // 物品图标
            if let definition = MockExplorationData.getItemDefinition(by: item.itemId) {
                ZStack {
                    Circle()
                        .fill(categoryColor(definition.category).opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: definition.category.iconName)
                        .font(.system(size: 18))
                        .foregroundColor(categoryColor(definition.category))
                }

                // 物品名称
                VStack(alignment: .leading, spacing: 2) {
                    Text(definition.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    // 品质（如有）
                    if let quality = item.quality {
                        Text(quality.displayName)
                            .font(.system(size: 11))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }

                Spacer()

                // 数量
                Text("x\(item.quantity)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.primary)

                // 对勾（带弹跳效果）
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(ApocalypseTheme.success)
                    .scaleEffect(checkmarkBounced.contains(index) ? 1.0 : 0.3)
                    .opacity(checkmarkBounced.contains(index) ? 1.0 : 0)
            }
        }
    }

    /// 分类颜色
    private func categoryColor(_ category: ItemCategory) -> Color {
        switch category {
        case .food:
            return Color(hex: "FF9800")
        case .water:
            return Color(hex: "2196F3")
        case .medical:
            return Color(hex: "F44336")
        case .material:
            return Color(hex: "795548")
        case .tool:
            return Color(hex: "607D8B")
        case .weapon:
            return Color(hex: "9E9E9E")
        case .clothing:
            return Color(hex: "9C27B0")
        case .misc:
            return ApocalypseTheme.textSecondary
        }
    }

    // MARK: - 确认按钮

    private var confirmButton: some View {
        Button {
            dismiss()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "checkmark")
                    .font(.system(size: 18, weight: .semibold))

                Text("确认收下")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(14)
            .shadow(color: ApocalypseTheme.primary.opacity(0.4), radius: 8, x: 0, y: 4)
        }
        .padding(.top, 8)
    }
}

// MARK: - Preview

#Preview {
    ExplorationResultView(result: MockExplorationData.sampleExplorationResult)
}
