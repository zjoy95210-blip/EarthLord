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

    /// 探索结果数据（成功时有值）- 来自 ExplorationManager
    let explorationResult: ExplorationResult?

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
    @State private var animatedDuration: Double = 0

    /// 已显示的奖励物品索引
    @State private var visibleRewardIndices: Set<Int> = []

    /// 对勾图标弹跳状态
    @State private var checkmarkBounced: Set<Int> = []

    /// 物品定义缓存
    @State private var itemDefinitions: [DBItemDefinition] = []

    // MARK: - 便捷初始化器

    /// 成功结果初始化
    init(explorationResult: ExplorationResult) {
        self.explorationResult = explorationResult
        self.errorMessage = nil
        self.onRetry = nil
    }

    /// 错误状态初始化
    init(errorMessage: String, onRetry: @escaping () -> Void) {
        self.explorationResult = nil
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
            } else if let result = explorationResult {
                // 成功状态
                successStateView(result: result)
            }
        }
        .onAppear {
            if explorationResult != nil {
                loadItemDefinitions()
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

    /// 加载物品定义
    private func loadItemDefinitions() {
        itemDefinitions = RewardGenerator.shared.getAllItemDefinitions()
        if itemDefinitions.isEmpty {
            // 如果缓存为空，异步加载
            Task {
                await RewardGenerator.shared.preloadCache()
                itemDefinitions = RewardGenerator.shared.getAllItemDefinitions()
            }
        }
    }

    /// 根据 ID 获取物品定义
    private func getItemDefinition(id: String) -> DBItemDefinition? {
        return itemDefinitions.first { $0.id == id }
    }

    // MARK: - 成功状态视图

    private func successStateView(result: ExplorationResult) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // 成就标题（包含奖励等级）
                achievementHeader(tier: result.rewardTier)
                    .opacity(showContent ? 1 : 0)
                    .scaleEffect(showContent ? 1 : 0.8)

                // 统计数据卡片
                statisticsCard(result: result)
                    .opacity(showStats ? 1 : 0)
                    .offset(y: showStats ? 0 : 20)

                // 奖励物品卡片
                if !result.rewardedItems.isEmpty {
                    rewardsCard(items: result.rewardedItems)
                        .opacity(showRewards ? 1 : 0)
                        .offset(y: showRewards ? 0 : 20)
                }

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
        guard let result = explorationResult else { return }

        // 距离数字动画（0.6秒完成）
        withAnimation(.easeOut(duration: 0.6)) {
            animatedDistance = result.distance
        }

        // 时长数字动画（0.5秒完成）
        withAnimation(.easeOut(duration: 0.5)) {
            animatedDuration = Double(result.duration)
        }
    }

    /// 奖励物品依次出现动画
    private func startRewardItemsAnimation() {
        guard let result = explorationResult else { return }

        for index in result.rewardedItems.indices {
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

    private func achievementHeader(tier: RewardTier) -> some View {
        let tierColor = Color(hex: tier.colorHex)

        return VStack(spacing: 16) {
            // 大图标（带光晕效果）
            ZStack {
                // 外圈光晕
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                tierColor.opacity(0.3),
                                tierColor.opacity(0)
                            ],
                            center: .center,
                            startRadius: 40,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)

                // 内圈
                Circle()
                    .fill(tierColor.opacity(0.15))
                    .frame(width: 100, height: 100)

                // 图标
                Image(systemName: tier.iconName)
                    .font(.system(size: 44))
                    .foregroundColor(tierColor)
            }

            // 大文字
            Text("探索完成！")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 奖励等级
            if tier != .none {
                HStack(spacing: 6) {
                    Image(systemName: tier.iconName)
                        .font(.system(size: 14))
                    Text(tier.displayName)
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(tierColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(tierColor.opacity(0.15))
                )
            } else {
                Text("距离不足，未获得奖励")
                    .font(.system(size: 15))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: - 统计数据卡片

    private func statisticsCard(result: ExplorationResult) -> some View {
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
            HStack {
                // 图标
                ZStack {
                    Circle()
                        .fill(Color(hex: "4CAF50").opacity(0.15))
                        .frame(width: 36, height: 36)

                    Image(systemName: "figure.walk")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "4CAF50"))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("行走距离")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    HStack(spacing: 12) {
                        // 本次
                        VStack(alignment: .leading, spacing: 2) {
                            Text("本次")
                                .font(.system(size: 11))
                                .foregroundColor(ApocalypseTheme.textMuted)
                            Text(formatDistance(animatedDistance))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(ApocalypseTheme.primary)
                        }

                        // 累计
                        VStack(alignment: .leading, spacing: 2) {
                            Text("累计")
                                .font(.system(size: 11))
                                .foregroundColor(ApocalypseTheme.textMuted)
                            Text(formatDistance(result.totalDistance))
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(ApocalypseTheme.textPrimary)
                        }
                    }
                }

                Spacer()
            }

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

                VStack(alignment: .leading, spacing: 4) {
                    Text("探索时长")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Text(formatDuration(animatedDuration))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .contentTransition(.numericText())
                }

                Spacer()
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    /// 格式化距离
    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.2f km", meters / 1000)
        } else {
            return String(format: "%.0f m", meters)
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

    private func rewardsCard(items: [RewardedItem]) -> some View {
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
                Text("\(items.count) 种")
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 分隔线
            Rectangle()
                .fill(ApocalypseTheme.textMuted.opacity(0.2))
                .frame(height: 1)

            // 物品列表
            VStack(spacing: 12) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
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
    private func rewardItemRow(item: RewardedItem, index: Int) -> some View {
        HStack(spacing: 12) {
            // 物品图标
            if let definition = getItemDefinition(id: item.itemId) {
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
    private func categoryColor(_ category: DBItemCategory) -> Color {
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

#Preview("成功结果") {
    ExplorationResultView(explorationResult: ExplorationResult(
        sessionId: UUID(),
        distance: 1500,
        duration: 900,
        rewardTier: .gold,
        rewardedItems: [
            RewardedItem(itemId: "water_bottle", quantity: 2, quality: .normal),
            RewardedItem(itemId: "canned_food", quantity: 1, quality: .fine),
            RewardedItem(itemId: "bandage", quantity: 3, quality: nil)
        ],
        startCoordinate: nil,
        endCoordinate: nil,
        totalDistance: 5000,
        totalDuration: 3600
    ))
}

#Preview("错误状态") {
    ExplorationResultView(errorMessage: "速度过快，探索已自动终止", onRetry: {})
}
