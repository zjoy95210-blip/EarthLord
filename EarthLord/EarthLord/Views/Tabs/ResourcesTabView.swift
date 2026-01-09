//
//  ResourcesTabView.swift
//  EarthLord
//
//  资源模块主入口页面
//  包含 POI、背包、已购、领地、交易 五个分段
//

import SwiftUI

/// 资源分段类型
enum ResourceSegment: Int, CaseIterable {
    case poi = 0
    case backpack = 1
    case purchased = 2
    case territory = 3
    case trade = 4

    var title: String {
        switch self {
        case .poi: return "POI"
        case .backpack: return "背包"
        case .purchased: return "已购"
        case .territory: return "领地"
        case .trade: return "交易"
        }
    }

    var icon: String {
        switch self {
        case .poi: return "mappin.circle.fill"
        case .backpack: return "bag.fill"
        case .purchased: return "cart.fill"
        case .territory: return "flag.fill"
        case .trade: return "arrow.left.arrow.right"
        }
    }
}

struct ResourcesTabView: View {

    // MARK: - State

    /// 当前选中的分段
    @State private var selectedSegment: ResourceSegment = .poi

    /// 交易开关状态（假数据）
    @State private var isTradeEnabled: Bool = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景色
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 分段选择器
                    segmentPicker
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 12)

                    // 内容区域
                    contentView
                }
            }
            .navigationTitle("资源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    // 交易开关
                    tradeToggle
                }
            }
        }
    }

    // MARK: - 分段选择器

    private var segmentPicker: some View {
        Picker("资源分段", selection: $selectedSegment) {
            ForEach(ResourceSegment.allCases, id: \.self) { segment in
                Text(segment.title)
                    .tag(segment)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - 交易开关

    private var tradeToggle: some View {
        HStack(spacing: 6) {
            Text("交易")
                .font(.system(size: 13))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Toggle("", isOn: $isTradeEnabled)
                .labelsHidden()
                .scaleEffect(0.8)
                .tint(ApocalypseTheme.primary)
        }
    }

    // MARK: - 内容区域

    @ViewBuilder
    private var contentView: some View {
        switch selectedSegment {
        case .poi:
            // POI 列表
            POIListView()

        case .backpack:
            // 背包
            BackpackView()

        case .purchased:
            // 已购 - 开发中
            developingPlaceholder(
                icon: "cart.fill",
                title: "已购物品",
                subtitle: "查看已购买的商品和订单记录"
            )

        case .territory:
            // 领地资源 - 开发中
            developingPlaceholder(
                icon: "flag.fill",
                title: "领地资源",
                subtitle: "管理领地内的资源产出"
            )

        case .trade:
            // 交易 - 开发中
            developingPlaceholder(
                icon: "arrow.left.arrow.right",
                title: "交易市场",
                subtitle: "与其他幸存者交换物资"
            )
        }
    }

    // MARK: - 开发中占位视图

    private func developingPlaceholder(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 20) {
            Spacer()

            // 图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.cardBackground)
                    .frame(width: 100, height: 100)

                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            // 标题
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 副标题
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // 开发中标签
            HStack(spacing: 6) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 12))

                Text("功能开发中")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(ApocalypseTheme.warning)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(ApocalypseTheme.warning.opacity(0.15))
            )
            .padding(.top, 10)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    ResourcesTabView()
}
