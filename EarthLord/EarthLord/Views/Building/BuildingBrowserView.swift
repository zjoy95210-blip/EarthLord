//
//  BuildingBrowserView.swift
//  EarthLord
//
//  建筑浏览器（分类Tab + 网格）
//

import SwiftUI

struct BuildingBrowserView: View {

    // MARK: - Properties

    /// 当前领地
    let territory: Territory

    /// 关闭回调
    let onDismiss: () -> Void

    /// 选择建筑回调
    let onSelectTemplate: (BuildingTemplate) -> Void

    /// 建筑管理器
    private let buildingManager = BuildingManager.shared

    /// 当前选中的分类筛选
    @State private var selectedFilter: BuildingCategoryFilter = .all

    /// 当前领地的建筑列表
    @State private var territoryBuildings: [PlayerBuilding] = []

    /// 是否正在加载
    @State private var isLoading = false

    // MARK: - Computed Properties

    /// 筛选后的模板列表
    private var filteredTemplates: [BuildingTemplate] {
        if let category = selectedFilter.toCategory {
            return buildingManager.templates.filter { $0.category == category }
        }
        return buildingManager.templates
    }

    /// 获取指定模板在当前领地的建筑数量
    private func existingCount(for templateId: String) -> Int {
        territoryBuildings.filter { $0.templateId == templateId }.count
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 分类筛选栏
                    CategoryButtonGroup(selectedFilter: $selectedFilter)
                        .padding(.vertical, 12)

                    // 建筑网格
                    if isLoading {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                        Spacer()
                    } else if filteredTemplates.isEmpty {
                        Spacer()
                        emptyView
                        Spacer()
                    } else {
                        buildingGrid
                    }
                }
            }
            .navigationTitle("建筑浏览器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        onDismiss()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
        .onAppear {
            loadTerritoryBuildings()
        }
    }

    // MARK: - 空视图
    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "building.2")
                .font(.system(size: 48))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("暂无该类型建筑")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    // MARK: - 建筑网格
    private var buildingGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 12
            ) {
                ForEach(filteredTemplates, id: \.id) { template in
                    BuildingCard(
                        template: template,
                        onTap: {
                            onSelectTemplate(template)
                        },
                        existingCount: existingCount(for: template.id)
                    )
                }
            }
            .padding()
        }
    }

    // MARK: - Methods

    /// 加载当前领地的建筑
    private func loadTerritoryBuildings() {
        isLoading = true

        Task {
            do {
                territoryBuildings = try await buildingManager.loadBuildings(for: territory.id)
            } catch {
                print("❌ [建筑浏览器] 加载建筑失败: \(error.localizedDescription)")
            }
            isLoading = false
        }
    }
}

// MARK: - Preview
#Preview {
    let sampleTerritory = Territory(
        id: UUID(),
        userId: UUID(),
        name: "测试领地",
        path: [
            ["lat": 31.23, "lon": 121.47],
            ["lat": 31.24, "lon": 121.47],
            ["lat": 31.24, "lon": 121.48],
            ["lat": 31.23, "lon": 121.48]
        ],
        area: 1000,
        pointCount: 4,
        isActive: true,
        startedAt: nil,
        completedAt: nil,
        createdAt: Date()
    )

    BuildingBrowserView(
        territory: sampleTerritory,
        onDismiss: {},
        onSelectTemplate: { _ in }
    )
}
