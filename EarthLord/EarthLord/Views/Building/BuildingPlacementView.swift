//
//  BuildingPlacementView.swift
//  EarthLord
//
//  建造确认页（资源检查 + 位置选择）
//

import SwiftUI
import CoreLocation

struct BuildingPlacementView: View {

    // MARK: - Properties

    /// 建筑模板
    let template: BuildingTemplate

    /// 领地
    let territory: Territory

    /// 关闭回调
    let onDismiss: () -> Void

    /// 建造成功回调
    let onConstructionStarted: (PlayerBuilding) -> Void

    /// 建筑管理器
    private let buildingManager = BuildingManager.shared

    /// 背包管理器
    private let inventoryManager = InventoryManager.shared

    /// 是否显示位置选择器
    @State private var showLocationPicker = false

    /// 选择的位置
    @State private var selectedLocation: CLLocationCoordinate2D?

    /// 是否正在建造
    @State private var isConstructing = false

    /// 错误信息
    @State private var errorMessage: String?

    /// 显示错误提示
    @State private var showError = false

    // MARK: - Computed Properties

    /// 资源列表
    private var resources: [ResourceInfo] {
        template.requiredMaterials.map { material in
            let owned = inventoryManager.getItemCount(itemId: material.itemId)
            let itemDef = inventoryManager.getItemDefinition(id: material.itemId)
            return ResourceInfo(
                itemId: material.itemId,
                name: itemDef?.name ?? material.itemId,
                iconName: itemDef?.category.iconName ?? "cube.box.fill",
                required: material.quantity,
                owned: owned
            )
        }
    }

    /// 是否所有材料都足够
    private var canBuild: Bool {
        resources.allSatisfy { $0.isSufficient }
    }

    /// 分类颜色
    private var categoryColor: Color {
        Color(hex: template.category.colorHex)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 建筑信息卡片
                        buildingInfoCard

                        // 资源需求
                        if !resources.isEmpty {
                            ResourceListView(resources: resources, title: "所需材料")
                        }

                        // 位置选择
                        locationSection

                        // 建造按钮
                        buildButton
                    }
                    .padding()
                }
            }
            .navigationTitle("确认建造")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        onDismiss()
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .sheet(isPresented: $showLocationPicker) {
                BuildingLocationPickerView(
                    territory: territory,
                    existingBuildings: buildingManager.getBuildings(territoryId: territory.id),
                    buildingTemplates: Dictionary(uniqueKeysWithValues: buildingManager.templates.map { ($0.id, $0) }),
                    onSelect: { location in
                        selectedLocation = location
                        showLocationPicker = false
                    },
                    onCancel: {
                        showLocationPicker = false
                    }
                )
            }
            .alert("建造失败", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "未知错误")
            }
            .onAppear {
                // 确保物品定义已加载（用于显示材料名称和图标）
                if inventoryManager.itemDefinitions.isEmpty {
                    Task { await inventoryManager.loadInventory() }
                }
            }
        }
    }

    // MARK: - 建筑信息卡片
    private var buildingInfoCard: some View {
        VStack(spacing: 16) {
            // 图标和基本信息
            HStack(spacing: 16) {
                // 建筑图标
                ZStack {
                    Circle()
                        .fill(categoryColor.opacity(0.2))
                        .frame(width: 64, height: 64)

                    Image(systemName: template.iconName)
                        .font(.system(size: 28))
                        .foregroundColor(categoryColor)
                }

                VStack(alignment: .leading, spacing: 6) {
                    // 名称
                    Text(template.name)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    // 分类标签
                    Text(template.category.displayName)
                        .font(.caption)
                        .foregroundColor(categoryColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(categoryColor.opacity(0.15))
                        .cornerRadius(8)
                }

                Spacer()

                // 建造时间
                VStack(alignment: .trailing, spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 20))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Text(template.formattedBuildTime)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }

            Divider()
                .background(ApocalypseTheme.textSecondary.opacity(0.3))

            // 描述
            Text(template.description)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 位置选择区域
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(ApocalypseTheme.primary)

                Text("建造位置")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            Button {
                showLocationPicker = true
            } label: {
                HStack {
                    if let location = selectedLocation {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("已选择位置")
                                .font(.subheadline)
                                .foregroundColor(ApocalypseTheme.textPrimary)

                            Text(String(format: "%.6f, %.6f", location.latitude, location.longitude))
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }
                    } else {
                        Text("点击选择位置")
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                .padding()
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            selectedLocation != nil
                            ? ApocalypseTheme.success.opacity(0.5)
                            : ApocalypseTheme.textSecondary.opacity(0.3),
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    // MARK: - 建造按钮
    private var buildButton: some View {
        Button {
            startConstruction()
        } label: {
            HStack {
                if isConstructing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "hammer.fill")
                }

                Text(isConstructing ? "建造中..." : "开始建造")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(canBuild && selectedLocation != nil && !isConstructing
                       ? ApocalypseTheme.primary
                       : ApocalypseTheme.textSecondary)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!canBuild || selectedLocation == nil || isConstructing)
    }

    // MARK: - Methods

    /// 开始建造
    private func startConstruction() {
        guard let location = selectedLocation else {
            errorMessage = "请先选择建造位置"
            showError = true
            return
        }

        isConstructing = true

        Task {
            do {
                let building = try await buildingManager.startConstruction(
                    templateId: template.id,
                    territoryId: territory.id,
                    location: location
                )

                await MainActor.run {
                    isConstructing = false
                    onConstructionStarted(building)
                }
            } catch {
                await MainActor.run {
                    isConstructing = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    let sampleTemplate = BuildingTemplate(
        id: "campfire",
        name: "篝火",
        description: "提供基础照明和温暖，是生存的起点",
        category: .survival,
        tier: 1,
        maxPerTerritory: 2,
        buildTime: 30,
        requiredMaterials: [
            RequiredMaterial(itemId: "wood", quantity: 5)
        ],
        maxLevel: 3,
        iconName: "flame.fill",
        effects: nil
    )

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

    BuildingPlacementView(
        template: sampleTemplate,
        territory: sampleTerritory,
        onDismiss: {},
        onConstructionStarted: { _ in }
    )
}
