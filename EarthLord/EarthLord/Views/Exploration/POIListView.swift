//
//  POIListView.swift
//  EarthLord
//
//  附近兴趣点列表页面
//  显示可探索的 POI 列表，支持分类筛选和搜索
//

import SwiftUI

struct POIListView: View {

    // MARK: - State

    /// 当前选中的筛选分类
    @State private var selectedCategory: String = "all"

    /// 是否正在搜索
    @State private var isSearching: Bool = false

    /// POI 列表数据
    @State private var poiList: [ExplorationPOI] = MockExplorationData.explorationPOIs

    /// 搜索按钮是否按下（用于缩放动画）
    @State private var isSearchButtonPressed: Bool = false

    /// 已显示的 POI ID 集合（用于错开淡入动画）
    @State private var visiblePOIs: Set<String> = []

    /// 模拟 GPS 坐标
    private let mockLatitude: Double = 22.5431
    private let mockLongitude: Double = 114.0579

    // MARK: - 筛选分类定义

    /// 筛选分类
    private let categories: [(id: String, name: String, icon: String)] = [
        ("all", "全部", "square.grid.2x2.fill"),
        ("hospital", "医院", "cross.case.fill"),
        ("supermarket", "超市", "cart.fill"),
        ("factory", "工厂", "building.2.fill"),
        ("pharmacy", "药店", "pills.fill"),
        ("gas_station", "加油站", "fuelpump.fill"),
    ]

    // MARK: - 计算属性

    /// 筛选后的 POI 列表
    private var filteredPOIs: [ExplorationPOI] {
        if selectedCategory == "all" {
            return poiList
        }
        return poiList.filter { poi in
            // 药店使用 hospital 类型
            if selectedCategory == "pharmacy" {
                return poi.type == "hospital" && poi.name.contains("药")
            }
            return poi.type == selectedCategory
        }
    }

    /// 已发现的 POI 数量
    private var discoveredCount: Int {
        poiList.filter { $0.discoveryStatus != .undiscovered }.count
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景色
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 状态栏
                statusBar

                // 搜索按钮
                searchButton
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                // 筛选工具栏
                filterToolbar
                    .padding(.bottom, 8)

                // POI 列表
                poiListView
            }
        }
        .navigationTitle("附近地点")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 状态栏

    private var statusBar: some View {
        HStack {
            // GPS 坐标
            HStack(spacing: 6) {
                Image(systemName: "location.fill")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.primary)

                Text(String(format: "%.4f, %.4f", mockLatitude, mockLongitude))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            // 发现数量
            HStack(spacing: 4) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.success)

                Text("附近发现 \(discoveredCount) 个地点")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(ApocalypseTheme.cardBackground)
    }

    // MARK: - 搜索按钮

    private var searchButton: some View {
        Button {
            performSearch()
        } label: {
            HStack(spacing: 10) {
                if isSearching {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)

                    Text("搜索中...")
                        .font(.system(size: 16, weight: .semibold))
                } else {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .semibold))

                    Text("搜索附近POI")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSearching ? ApocalypseTheme.textSecondary : ApocalypseTheme.primary)
            )
            .shadow(color: ApocalypseTheme.primary.opacity(isSearching ? 0 : 0.4),
                    radius: 8, x: 0, y: 4)
        }
        .scaleEffect(isSearchButtonPressed ? 0.96 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isSearchButtonPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isSearching {
                        isSearchButtonPressed = true
                    }
                }
                .onEnded { _ in
                    isSearchButtonPressed = false
                }
        )
        .disabled(isSearching)
    }

    // MARK: - 筛选工具栏

    private var filterToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(categories, id: \.id) { category in
                    filterButton(
                        id: category.id,
                        name: category.name,
                        icon: category.icon
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }

    /// 筛选按钮
    private func filterButton(id: String, name: String, icon: String) -> some View {
        let isSelected = selectedCategory == id

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

    // MARK: - POI 列表

    private var poiListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if filteredPOIs.isEmpty {
                    emptyStateView
                } else {
                    ForEach(Array(filteredPOIs.enumerated()), id: \.element.id) { index, poi in
                        NavigationLink(destination: POIDetailView(poi: poi)) {
                            POICardView(poi: poi)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .opacity(visiblePOIs.contains(poi.id) ? 1 : 0)
                        .offset(y: visiblePOIs.contains(poi.id) ? 0 : 20)
                        .onAppear {
                            // 错开 0.1 秒依次淡入
                            let delay = Double(index) * 0.1
                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    _ = visiblePOIs.insert(poi.id)
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
            // 初次加载时触发动画
            triggerListAnimation()
        }
        .onChange(of: selectedCategory) { _, _ in
            // 切换分类时重置并重新触发动画
            visiblePOIs.removeAll()
            triggerListAnimation()
        }
    }

    /// 触发列表淡入动画
    private func triggerListAnimation() {
        for (index, poi) in filteredPOIs.enumerated() {
            let delay = Double(index) * 0.1
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeOut(duration: 0.3)) {
                    _ = visiblePOIs.insert(poi.id)
                }
            }
        }
    }

    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 48))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("未发现该类型的地点")
                .font(.system(size: 16))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("尝试搜索或切换其他分类")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Actions

    /// 执行搜索
    private func performSearch() {
        isSearching = true

        // 模拟网络请求 1.5 秒
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isSearching = false
            // 这里可以添加刷新数据的逻辑
            print("🔍 [POI] 搜索完成")
        }
    }

}

// MARK: - POI 卡片视图

struct POICardView: View {

    let poi: ExplorationPOI

    /// 获取 POI 类型对应的颜色
    private var typeColor: Color {
        switch poi.type {
        case "hospital":
            return poi.name.contains("药") ? Color(hex: "9C27B0") : Color(hex: "F44336")  // 药店紫色，医院红色
        case "supermarket":
            return Color(hex: "4CAF50")  // 绿色
        case "factory":
            return Color(hex: "9E9E9E")  // 灰色
        case "gas_station":
            return Color(hex: "FF9800")  // 橙色
        default:
            return ApocalypseTheme.textSecondary
        }
    }

    /// 获取 POI 类型图标
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

    /// 发现状态文字
    private var statusText: String {
        switch poi.discoveryStatus {
        case .undiscovered:
            return "未发现"
        case .discovered:
            return "已发现"
        case .looted:
            return "已搜刮"
        }
    }

    /// 发现状态颜色
    private var statusColor: Color {
        switch poi.discoveryStatus {
        case .undiscovered:
            return ApocalypseTheme.textMuted
        case .discovered:
            return ApocalypseTheme.success
        case .looted:
            return ApocalypseTheme.textSecondary
        }
    }

    /// 物资状态文字
    private var resourceText: String {
        switch poi.resourceStatus {
        case .hasResources:
            return "有物资"
        case .empty:
            return "已搜空"
        case .unknown:
            return "未知"
        }
    }

    /// 物资状态颜色
    private var resourceColor: Color {
        switch poi.resourceStatus {
        case .hasResources:
            return ApocalypseTheme.warning
        case .empty:
            return ApocalypseTheme.textMuted
        case .unknown:
            return ApocalypseTheme.textSecondary
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            // 类型图标
            ZStack {
                Circle()
                    .fill(typeColor.opacity(0.15))
                    .frame(width: 50, height: 50)

                Image(systemName: typeIcon)
                    .font(.system(size: 22))
                    .foregroundColor(typeColor)
            }

            // 信息区域
            VStack(alignment: .leading, spacing: 6) {
                // 名称和类型
                HStack {
                    Text(poi.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Spacer()

                    // 类型标签
                    Text(poi.typeDisplayName)
                        .font(.system(size: 11))
                        .foregroundColor(typeColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(typeColor.opacity(0.15))
                        )
                }

                // 状态行
                HStack(spacing: 12) {
                    // 发现状态
                    HStack(spacing: 4) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 6, height: 6)

                        Text(statusText)
                            .font(.system(size: 12))
                            .foregroundColor(statusColor)
                    }

                    // 物资状态
                    HStack(spacing: 4) {
                        Image(systemName: poi.resourceStatus == .hasResources ? "shippingbox.fill" : "shippingbox")
                            .font(.system(size: 10))
                            .foregroundColor(resourceColor)

                        Text(resourceText)
                            .font(.system(size: 12))
                            .foregroundColor(resourceColor)
                    }

                    Spacer()

                    // 箭头
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    poi.canLoot ? ApocalypseTheme.warning.opacity(0.3) : Color.clear,
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        POIListView()
    }
}
