//
//  BackpackView.swift
//  EarthLord
//
//  背包管理页面
//  显示玩家背包中的物品，支持搜索、筛选和管理
//

import SwiftUI

struct BackpackView: View {

    // MARK: - State

    /// 搜索文字
    @State private var searchText: String = ""

    /// 当前选中的分类
    @State private var selectedCategory: String = "all"

    /// 背包物品列表
    @State private var backpackItems: [BackpackItem] = MockExplorationData.backpackItems

    /// 已显示的物品 ID 集合（用于动画）
    @State private var visibleItems: Set<UUID> = []

    /// 动画容量值（用于数字跳动效果）
    @State private var animatedCapacity: Double = 0

    // MARK: - 常量

    /// 背包最大容量
    private let maxCapacity: Double = 100.0

    /// 当前使用容量（模拟值）
    private var usedCapacity: Double {
        // 计算实际重量作为容量
        var total: Double = 0
        for item in backpackItems {
            if let definition = MockExplorationData.getItemDefinition(by: item.itemId) {
                total += definition.weight * Double(item.quantity)
            }
        }
        return total
    }

    /// 容量使用百分比
    private var capacityPercentage: Double {
        return min(usedCapacity / maxCapacity, 1.0)
    }

    /// 分类列表
    private let categories: [(id: String, name: String, icon: String)] = [
        ("all", "全部", "square.grid.2x2.fill"),
        ("food", "食物", "fork.knife"),
        ("water", "水", "drop.fill"),
        ("material", "材料", "shippingbox.fill"),
        ("tool", "工具", "wrench.and.screwdriver.fill"),
        ("medical", "医疗", "cross.case.fill"),
    ]

    // MARK: - 计算属性

    /// 筛选后的物品列表
    private var filteredItems: [BackpackItem] {
        var items = backpackItems

        // 按分类筛选
        if selectedCategory != "all" {
            items = items.filter { item in
                if let definition = MockExplorationData.getItemDefinition(by: item.itemId) {
                    return definition.category.rawValue == selectedCategory
                }
                return false
            }
        }

        // 按搜索文字筛选
        if !searchText.isEmpty {
            items = items.filter { item in
                if let definition = MockExplorationData.getItemDefinition(by: item.itemId) {
                    return definition.name.localizedCaseInsensitiveContains(searchText)
                }
                return false
            }
        }

        return items
    }

    /// 物品总数量
    private var totalItemCount: Int {
        backpackItems.reduce(0) { $0 + $1.quantity }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景色
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 容量状态卡
                capacityCard
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                // 搜索和筛选
                searchAndFilterSection
                    .padding(.top, 16)

                // 物品列表
                itemListView
                    .padding(.top, 8)
            }
        }
        .navigationTitle("我的背包")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 容量状态卡

    private var capacityCard: some View {
        VStack(spacing: 12) {
            // 标题行
            HStack {
                Image(systemName: "bag.fill")
                    .font(.system(size: 18))
                    .foregroundColor(ApocalypseTheme.primary)

                Text("背包容量")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                // 容量数值（使用动画值）
                Text(String(format: "%.1f / %.0f kg", animatedCapacity, maxCapacity))
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(capacityTextColor)
                    .contentTransition(.numericText())
            }

            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景
                    RoundedRectangle(cornerRadius: 6)
                        .fill(ApocalypseTheme.background)
                        .frame(height: 12)

                    // 进度
                    RoundedRectangle(cornerRadius: 6)
                        .fill(capacityBarColor)
                        .frame(width: geometry.size.width * capacityPercentage, height: 12)
                        .animation(.easeInOut(duration: 0.3), value: capacityPercentage)
                }
            }
            .frame(height: 12)

            // 警告文字（容量超过90%时显示）
            if capacityPercentage > 0.9 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))

                    Text("背包快满了！")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(ApocalypseTheme.danger)
                .transition(.opacity.combined(with: .scale))
            }

            // 物品数量统计
            HStack {
                Text("共 \(backpackItems.count) 种物品")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()

                Text("总计 \(totalItemCount) 个")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
        .animation(.easeInOut(duration: 0.3), value: capacityPercentage > 0.9)
    }

    /// 容量进度条颜色
    private var capacityBarColor: Color {
        if capacityPercentage > 0.9 {
            return ApocalypseTheme.danger  // 红色
        } else if capacityPercentage > 0.7 {
            return ApocalypseTheme.warning  // 黄色
        } else {
            return ApocalypseTheme.success  // 绿色
        }
    }

    /// 容量文字颜色
    private var capacityTextColor: Color {
        if capacityPercentage > 0.9 {
            return ApocalypseTheme.danger
        } else if capacityPercentage > 0.7 {
            return ApocalypseTheme.warning
        } else {
            return ApocalypseTheme.textPrimary
        }
    }

    // MARK: - 搜索和筛选

    private var searchAndFilterSection: some View {
        VStack(spacing: 12) {
            // 搜索框
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundColor(ApocalypseTheme.textMuted)

                TextField("搜索物品...", text: $searchText)
                    .font(.system(size: 15))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(ApocalypseTheme.cardBackground)
            )
            .padding(.horizontal, 16)

            // 分类按钮
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(categories, id: \.id) { category in
                        categoryButton(
                            id: category.id,
                            name: category.name,
                            icon: category.icon
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    /// 分类按钮
    private func categoryButton(id: String, name: String, icon: String) -> some View {
        let isSelected = selectedCategory == id
        let itemCount = countItemsInCategory(id)

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedCategory = id
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))

                Text(name)
                    .font(.system(size: 13, weight: .medium))

                if id != "all" && itemCount > 0 {
                    Text("(\(itemCount))")
                        .font(.system(size: 11))
                        .opacity(0.8)
                }
            }
            .foregroundColor(isSelected ? .white : ApocalypseTheme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
            )
        }
    }

    /// 计算某分类的物品数量
    private func countItemsInCategory(_ categoryId: String) -> Int {
        if categoryId == "all" {
            return backpackItems.count
        }
        return backpackItems.filter { item in
            if let definition = MockExplorationData.getItemDefinition(by: item.itemId) {
                return definition.category.rawValue == categoryId
            }
            return false
        }.count
    }

    // MARK: - 物品列表

    private var itemListView: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if filteredItems.isEmpty {
                    emptyStateView
                } else {
                    ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                        if let definition = MockExplorationData.getItemDefinition(by: item.itemId) {
                            ItemCardView(item: item, definition: definition)
                                .opacity(visibleItems.contains(item.id) ? 1 : 0)
                                .offset(y: visibleItems.contains(item.id) ? 0 : 15)
                                .onAppear {
                                    // 错开动画
                                    let delay = Double(index) * 0.08
                                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                        withAnimation(.easeOut(duration: 0.25)) {
                                            _ = visibleItems.insert(item.id)
                                        }
                                    }
                                }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .onAppear {
            // 初始化动画值
            triggerItemListAnimation()
            animateCapacity()
        }
        .onChange(of: selectedCategory) { _, _ in
            // 切换分类时重置动画
            visibleItems.removeAll()
            triggerItemListAnimation()
        }
    }

    /// 触发物品列表动画
    private func triggerItemListAnimation() {
        for (index, item) in filteredItems.enumerated() {
            let delay = Double(index) * 0.08
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeOut(duration: 0.25)) {
                    _ = visibleItems.insert(item.id)
                }
            }
        }
    }

    /// 容量数字动画
    private func animateCapacity() {
        withAnimation(.easeOut(duration: 0.8)) {
            animatedCapacity = usedCapacity
        }
    }

    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            // 根据情况显示不同的空状态
            if backpackItems.isEmpty {
                // 背包完全为空的情况
                Image(systemName: "bag")
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.textMuted)

                Text("背包空空如也")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text("去探索收集物资吧")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textMuted)

            } else if !searchText.isEmpty {
                // 搜索没有结果的情况
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.textMuted)

                Text("没有找到相关物品")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text("尝试其他搜索词")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textMuted)

            } else {
                // 分类筛选没有结果的情况
                Image(systemName: "tray")
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.textMuted)

                Text("该分类下暂无物品")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text("切换其他分类查看")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 80)
    }
}

// MARK: - 物品卡片视图

struct ItemCardView: View {

    let item: BackpackItem
    let definition: ItemDefinition

    /// 分类图标
    private var categoryIcon: String {
        return definition.category.iconName
    }

    /// 分类颜色
    private var categoryColor: Color {
        switch definition.category {
        case .food:
            return Color(hex: "FF9800")  // 橙色
        case .water:
            return Color(hex: "2196F3")  // 蓝色
        case .medical:
            return Color(hex: "F44336")  // 红色
        case .material:
            return Color(hex: "795548")  // 棕色
        case .tool:
            return Color(hex: "607D8B")  // 蓝灰色
        case .weapon:
            return Color(hex: "9E9E9E")  // 灰色
        case .clothing:
            return Color(hex: "9C27B0")  // 紫色
        case .misc:
            return ApocalypseTheme.textSecondary
        }
    }

    /// 稀有度颜色
    private var rarityColor: Color {
        return Color(hex: definition.rarity.colorHex)
    }

    /// 总重量
    private var totalWeight: Double {
        return definition.weight * Double(item.quantity)
    }

    var body: some View {
        HStack(spacing: 12) {
            // 分类图标
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.15))
                    .frame(width: 46, height: 46)

                Image(systemName: categoryIcon)
                    .font(.system(size: 20))
                    .foregroundColor(categoryColor)
            }

            // 物品信息
            VStack(alignment: .leading, spacing: 6) {
                // 第一行：名称和稀有度
                HStack(spacing: 8) {
                    Text(definition.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    // 稀有度标签
                    Text(definition.rarity.displayName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(rarityColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(rarityColor.opacity(0.15))
                        )
                }

                // 第二行：数量、重量、品质
                HStack(spacing: 12) {
                    // 数量
                    HStack(spacing: 3) {
                        Text("x\(item.quantity)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(ApocalypseTheme.primary)
                    }

                    // 重量
                    HStack(spacing: 3) {
                        Image(systemName: "scalemass")
                            .font(.system(size: 10))
                        Text(String(format: "%.1fkg", totalWeight))
                            .font(.system(size: 12))
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)

                    // 品质（如有）
                    if let quality = item.quality {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                            Text(quality.displayName)
                                .font(.system(size: 12))
                        }
                        .foregroundColor(qualityColor(quality))
                    }
                }
            }

            Spacer()

            // 操作按钮
            VStack(spacing: 6) {
                // 使用按钮
                Button {
                    handleUse()
                } label: {
                    Text("使用")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(ApocalypseTheme.primary)
                        )
                }

                // 存储按钮
                Button {
                    handleStore()
                } label: {
                    Text("存储")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .stroke(ApocalypseTheme.textMuted.opacity(0.5), lineWidth: 1)
                        )
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    /// 品质颜色
    private func qualityColor(_ quality: ItemQuality) -> Color {
        switch quality {
        case .broken:
            return Color(hex: "F44336")  // 红色
        case .worn:
            return Color(hex: "FF9800")  // 橙色
        case .normal:
            return ApocalypseTheme.textSecondary
        case .fine:
            return Color(hex: "4CAF50")  // 绿色
        case .pristine:
            return Color(hex: "2196F3")  // 蓝色
        }
    }

    /// 处理使用
    private func handleUse() {
        print("🎒 [背包] 使用物品: \(definition.name) x1")
        print("   - 剩余数量: \(item.quantity - 1)")
        // TODO: 实现使用逻辑
    }

    /// 处理存储
    private func handleStore() {
        print("🎒 [背包] 存储物品: \(definition.name) x\(item.quantity)")
        print("   - 将移入仓库")
        // TODO: 实现存储逻辑
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BackpackView()
    }
}
