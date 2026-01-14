//
//  ScavengeResultView.swift
//  EarthLord
//
//  搜刮结果展示
//  显示从 POI 搜刮获得的物品
//

import SwiftUI
import CoreLocation

/// 搜刮结果展示
struct ScavengeResultView: View {

    // MARK: - Properties

    let rewards: [RewardedItem]
    let poi: ScavengePOI

    @Environment(\.dismiss) private var dismiss

    /// 物品定义缓存
    @State private var itemDefinitions: [DBItemDefinition] = []

    /// 动画状态
    @State private var showContent: Bool = false
    @State private var visibleItems: Set<Int> = []

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
                    }
                }
                .opacity(showContent ? 1.0 : 0.0)

                // 物品列表
                if rewards.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 40))
                            .foregroundColor(ApocalypseTheme.textMuted)
                        Text("这里已经被搜刮一空了...")
                            .font(.system(size: 15))
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                    .padding(.vertical, 30)
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(Array(rewards.enumerated()), id: \.offset) { index, item in
                                rewardItemRow(item: item, index: index)
                                    .opacity(visibleItems.contains(index) ? 1.0 : 0.0)
                                    .offset(x: visibleItems.contains(index) ? 0 : -30)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .frame(maxHeight: 300)
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
            loadItemDefinitions()
            startAnimations()
        }
    }

    /// 物品行
    @ViewBuilder
    private func rewardItemRow(item: RewardedItem, index: Int) -> some View {
        if let def = itemDefinitions.first(where: { $0.id == item.itemId }) {
            HStack(spacing: 14) {
                // 图标
                ZStack {
                    Circle()
                        .fill(rarityColor(for: def.rarity).opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: categoryIcon(for: def.category))
                        .font(.system(size: 20))
                        .foregroundColor(rarityColor(for: def.rarity))
                }

                // 名称和品质
                VStack(alignment: .leading, spacing: 2) {
                    Text(def.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    HStack(spacing: 6) {
                        Text(def.rarity.displayName)
                            .font(.system(size: 11))
                            .foregroundColor(rarityColor(for: def.rarity))

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
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ApocalypseTheme.cardBackground)
            )
        }
    }

    /// 加载物品定义
    private func loadItemDefinitions() {
        itemDefinitions = RewardGenerator.shared.getAllItemDefinitions()
    }

    /// 启动动画
    private func startAnimations() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            showContent = true
        }

        // 依次显示物品
        for index in rewards.indices {
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
        rewards: [
            RewardedItem(itemId: "water_bottle", quantity: 2, quality: .normal),
            RewardedItem(itemId: "canned_food", quantity: 1, quality: .fine)
        ],
        poi: ScavengePOI(
            id: "test_poi",
            name: "测试超市",
            category: .supermarket,
            coordinate: .init(latitude: 0, longitude: 0),
            status: .depleted,
            lastScavengedAt: Date(),
            distanceToPlayer: 32
        )
    )
}
