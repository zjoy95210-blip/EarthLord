//
//  ScavengeResultView.swift
//  EarthLord
//
//  搜刮结果展示
//  显示从 POI 搜刮获得的 AI 生成物品，包含独特名称和背景故事
//

import SwiftUI
import CoreLocation

/// 搜刮结果展示
struct ScavengeResultView: View {

    // MARK: - Properties

    let aiRewards: [AIRewardedItem]
    let poi: ScavengePOI

    @Environment(\.dismiss) private var dismiss

    /// 动画状态
    @State private var showContent: Bool = false
    @State private var visibleItems: Set<Int> = []
    @State private var expandedStories: Set<Int> = []

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // 成功图标
                ZStack {
                    Circle()
                        .fill(ApocalypseTheme.success.opacity(0.15))
                        .frame(width: 80, height: 80)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(ApocalypseTheme.success)
                }
                .scaleEffect(showContent ? 1.0 : 0.5)
                .opacity(showContent ? 1.0 : 0.0)

                // 标题
                VStack(spacing: 8) {
                    Text("搜刮完成!")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    HStack(spacing: 6) {
                        Image(systemName: poi.category.iconName)
                            .font(.system(size: 14))
                            .foregroundColor(poi.category.color)
                        Text(poi.name)
                            .font(.system(size: 14))
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        // 危险等级标签
                        Text(poi.dangerLevel.displayName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color(hex: poi.dangerLevel.colorHex))
                            )
                    }
                }
                .opacity(showContent ? 1.0 : 0.0)

                // 物品列表
                if aiRewards.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(Array(aiRewards.enumerated()), id: \.element.id) { index, item in
                                aiRewardItemRow(item: item, index: index)
                                    .opacity(visibleItems.contains(index) ? 1.0 : 0.0)
                                    .offset(x: visibleItems.contains(index) ? 0 : -30)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .frame(maxHeight: 400)
                }

                Spacer()

                // 确认按钮
                Button {
                    dismiss()
                } label: {
                    Text("收下物资")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(ApocalypseTheme.primary)
                        )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
                .opacity(showContent ? 1.0 : 0.0)
            }
            .padding(.top, 40)
        }
        .onAppear {
            startAnimations()
        }
    }

    // MARK: - Views

    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundColor(ApocalypseTheme.textMuted)
            Text("这里已经被搜刮一空了...")
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .padding(.vertical, 30)
    }

    /// AI 物品行（含故事）
    @ViewBuilder
    private func aiRewardItemRow(item: AIRewardedItem, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 物品信息
            HStack(spacing: 14) {
                // 图标
                ZStack {
                    Circle()
                        .fill(rarityColor(for: item.rarity).opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: categoryIcon(for: item.category))
                        .font(.system(size: 20))
                        .foregroundColor(rarityColor(for: item.rarity))
                }

                // 名称和稀有度
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(item.rarity.displayName)
                            .font(.system(size: 11))
                            .foregroundColor(rarityColor(for: item.rarity))

                        if let quality = item.quality {
                            Text("[\(quality.displayName)]")
                                .font(.system(size: 11))
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }
                    }
                }

                Spacer()

                // 数量
                Text("x\(item.quantity)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(ApocalypseTheme.primary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.3)) {
                    if expandedStories.contains(index) {
                        expandedStories.remove(index)
                    } else {
                        expandedStories.insert(index)
                    }
                }
            }

            // 故事（可展开）
            if expandedStories.contains(index) {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .background(ApocalypseTheme.textMuted.opacity(0.3))

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 12))
                            .foregroundColor(ApocalypseTheme.textMuted)

                        Text(item.story)
                            .font(.system(size: 13))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .lineSpacing(4)
                    }
                }
                .padding(.top, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // 展开提示
            if !expandedStories.contains(index) {
                HStack {
                    Spacer()
                    Text("点击查看故事")
                        .font(.system(size: 10))
                        .foregroundColor(ApocalypseTheme.textMuted)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - Helpers

    /// 启动动画
    private func startAnimations() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            showContent = true
        }

        // 依次显示物品
        for index in aiRewards.indices {
            let delay = 0.3 + Double(index) * 0.15
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    _ = visibleItems.insert(index)
                }
            }
        }
    }

    /// 稀有度颜色
    private func rarityColor(for rarity: DBItemRarity) -> Color {
        Color(hex: rarity.colorHex)
    }

    /// 分类图标
    private func categoryIcon(for category: DBItemCategory) -> String {
        switch category {
        case .food: return "fork.knife"
        case .water: return "drop.fill"
        case .medical: return "cross.case.fill"
        case .material: return "cube.fill"
        case .tool: return "wrench.fill"
        case .weapon: return "shield.fill"
        case .clothing: return "tshirt.fill"
        case .misc: return "shippingbox.fill"
        }
    }
}

// MARK: - Preview

#Preview {
    ScavengeResultView(
        aiRewards: [
            AIRewardedItem(
                itemId: "ai_medical_001",
                name: "「最后的希望」应急包",
                category: .medical,
                rarity: .epic,
                story: "这个急救包上贴着一张便签：'给值夜班的自己准备的'。便签已经褪色，主人再也没能用上它...",
                quantity: 1,
                quality: .pristine
            ),
            AIRewardedItem(
                itemId: "ai_food_002",
                name: "护士站的咖啡罐头",
                category: .food,
                rarity: .rare,
                story: "罐头上写着'夜班续命神器'。末日来临时，护士们大概正在喝着咖啡讨论患者病情。",
                quantity: 2,
                quality: nil
            ),
            AIRewardedItem(
                itemId: "ai_medical_003",
                name: "急诊科常备止痛片",
                category: .medical,
                rarity: .uncommon,
                story: "瓶身上还贴着患者的名字，他大概永远不会来取了。",
                quantity: 3,
                quality: .normal
            )
        ],
        poi: ScavengePOI(
            id: "test_poi",
            name: "协和医院急诊室",
            category: .hospital,
            coordinate: .init(latitude: 0, longitude: 0),
            dangerLevel: .high,
            status: .depleted,
            lastScavengedAt: Date(),
            distanceToPlayer: 32
        )
    )
}
