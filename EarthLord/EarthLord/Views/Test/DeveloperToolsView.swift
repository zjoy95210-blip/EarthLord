//
//  DeveloperToolsView.swift
//  EarthLord
//
//  开发者工具 - 用于测试和调试
//

import SwiftUI
import CoreLocation

struct DeveloperToolsView: View {

    // MARK: - Properties

    private let buildingManager = BuildingManager.shared
    private let inventoryManager = InventoryManager.shared
    private let territoryManager = TerritoryManager.shared

    @State private var showAddMaterialAlert = false
    @State private var selectedMaterial = "wood"
    @State private var materialQuantity = 100

    @State private var message: String?
    @State private var showMessage = false

    // 可添加的材料列表
    private let materials = [
        ("wood", "木材"),
        ("stone", "石头"),
        ("fiber", "纤维"),
        ("metal", "金属"),
        ("cloth", "布料"),
        ("rope", "绳子"),
        ("leather", "皮革"),
        ("glass", "玻璃")
    ]

    // MARK: - Body

    var body: some View {
        List {
            // 建筑系统
            buildingSection

            // 材料管理
            materialSection

            // 数据查看
            dataSection

            // 危险操作
            dangerSection
        }
        .navigationTitle("开发者工具")
        .navigationBarTitleDisplayMode(.large)
        .alert("添加材料", isPresented: $showAddMaterialAlert) {
            TextField("数量", value: $materialQuantity, format: .number)
                .keyboardType(.numberPad)
            Button("取消", role: .cancel) {}
            Button("添加") {
                addMaterial()
            }
        } message: {
            let materialName = materials.first { $0.0 == selectedMaterial }?.1 ?? selectedMaterial
            Text("添加 \(materialName) 到背包")
        }
        .alert("提示", isPresented: $showMessage) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
    }

    // MARK: - 建筑系统区域

    private var buildingSection: some View {
        Section {
            // 快速建造篝火（测试用）
            Button {
                quickBuildCampfire()
            } label: {
                Label("快速建造篝火", systemImage: "flame.fill")
                    .foregroundColor(ApocalypseTheme.warning)
            }

            // 查看所有建筑模板
            NavigationLink {
                BuildingTemplateListView()
            } label: {
                Label("建筑模板列表", systemImage: "building.2")
            }

            // 查看我的建筑
            NavigationLink {
                MyBuildingsListView()
            } label: {
                Label("我的建筑", systemImage: "hammer")
            }

            // 刷新建筑数据
            Button {
                refreshBuildingData()
            } label: {
                Label("刷新建筑数据", systemImage: "arrow.clockwise")
            }
        } header: {
            Text("建筑系统")
        }
    }

    // MARK: - 材料管理区域

    private var materialSection: some View {
        Section {
            ForEach(materials, id: \.0) { material in
                Button {
                    selectedMaterial = material.0
                    showAddMaterialAlert = true
                } label: {
                    HStack {
                        Text("添加 \(material.1)")
                            .foregroundColor(ApocalypseTheme.textPrimary)
                        Spacer()
                        Text("+100")
                            .foregroundColor(ApocalypseTheme.success)
                    }
                }
            }
        } header: {
            Text("快速添加材料")
        }
    }

    // MARK: - 数据查看区域

    private var dataSection: some View {
        Section {
            // 背包物品数量
            HStack {
                Text("背包物品")
                Spacer()
                Text("\(inventoryManager.items.count) 种")
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 建筑模板数量
            HStack {
                Text("建筑模板")
                Spacer()
                Text("\(buildingManager.templates.count) 个")
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 我的建筑数量
            HStack {
                Text("我的建筑")
                Spacer()
                Text("\(buildingManager.buildings.count) 个")
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 我的领地数量
            HStack {
                Text("我的领地")
                Spacer()
                Text("\(territoryManager.territories.count) 块")
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        } header: {
            Text("数据统计")
        }
    }

    // MARK: - 危险操作区域

    private var dangerSection: some View {
        Section {
            Button(role: .destructive) {
                clearAllBuildings()
            } label: {
                Label("清空所有建筑", systemImage: "trash")
            }
        } header: {
            Text("危险操作")
        } footer: {
            Text("清空操作不可恢复，请谨慎使用")
        }
    }

    // MARK: - Methods

    /// 快速建造篝火（测试用，自动添加材料并建造）
    private func quickBuildCampfire() {
        Task {
            // 先添加所需材料
            do {
                try await inventoryManager.addItem(itemId: "wood", quantity: 10, quality: nil)
                try await inventoryManager.addItem(itemId: "stone", quantity: 10, quality: nil)
            } catch {
                message = "添加材料失败: \(error.localizedDescription)"
                showMessage = true
                return
            }

            // 获取第一个领地
            do {
                let territories = try await territoryManager.loadMyTerritories()
                guard let territory = territories.first else {
                    message = "没有领地，请先圈一块领地"
                    showMessage = true
                    return
                }

                // 获取领地中心作为建造位置
                let coords = territory.toCoordinates()
                let centerLat = coords.map { $0.latitude }.reduce(0, +) / Double(max(coords.count, 1))
                let centerLon = coords.map { $0.longitude }.reduce(0, +) / Double(max(coords.count, 1))
                let location = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)

                // 建造篝火
                let building = try await buildingManager.startConstruction(
                    templateId: "campfire",
                    territoryId: territory.id,
                    location: location
                )

                message = "篝火建造成功！位置: \(territory.displayName)"
                showMessage = true
                print("✅ 快速建造篝火成功: \(building.id)")

            } catch {
                message = "建造失败: \(error.localizedDescription)"
                showMessage = true
            }
        }
    }

    /// 添加材料
    private func addMaterial() {
        Task {
            do {
                try await inventoryManager.addItem(
                    itemId: selectedMaterial,
                    quantity: materialQuantity,
                    quality: nil
                )
                let materialName = materials.first { $0.0 == selectedMaterial }?.1 ?? selectedMaterial
                message = "成功添加 \(materialQuantity) 个 \(materialName)"
                showMessage = true
            } catch {
                message = "添加失败: \(error.localizedDescription)"
                showMessage = true
            }
        }
    }

    /// 刷新建筑数据
    private func refreshBuildingData() {
        Task {
            do {
                try await buildingManager.fetchAllPlayerBuildings()
                message = "建筑数据已刷新"
                showMessage = true
            } catch {
                message = "刷新失败: \(error.localizedDescription)"
                showMessage = true
            }
        }
    }

    /// 清空所有建筑
    private func clearAllBuildings() {
        Task {
            for building in buildingManager.buildings {
                do {
                    try await buildingManager.demolishBuilding(buildingId: building.id)
                } catch {
                    print("❌ 删除建筑失败: \(error)")
                }
            }
            message = "已清空所有建筑"
            showMessage = true
        }
    }
}

// MARK: - 建筑模板列表视图

struct BuildingTemplateListView: View {

    private let buildingManager = BuildingManager.shared

    var body: some View {
        List {
            ForEach(BuildingCategory.allCases, id: \.self) { category in
                Section {
                    let templates = buildingManager.getTemplates(category: category)
                    ForEach(templates, id: \.id) { template in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: template.iconName)
                                    .foregroundColor(Color(hex: template.category.colorHex))

                                Text(template.name)
                                    .font(.headline)

                                Spacer()

                                Text("Tier \(template.tier)")
                                    .font(.caption)
                                    .foregroundColor(ApocalypseTheme.textSecondary)
                            }

                            Text(template.description)
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textSecondary)

                            HStack {
                                Text("建造时间: \(template.formattedBuildTime)")
                                Spacer()
                                Text("上限: \(template.maxPerTerritory)")
                            }
                            .font(.caption2)
                            .foregroundColor(ApocalypseTheme.textMuted)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text(category.displayName)
                }
            }
        }
        .navigationTitle("建筑模板")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 我的建筑列表视图

struct MyBuildingsListView: View {

    private let buildingManager = BuildingManager.shared

    @State private var isLoading = false

    var body: some View {
        List {
            if buildingManager.buildings.isEmpty {
                Text("暂无建筑")
                    .foregroundColor(ApocalypseTheme.textSecondary)
            } else {
                ForEach(buildingManager.buildings) { building in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            if let template = buildingManager.getTemplate(id: building.templateId) {
                                Image(systemName: template.iconName)
                                    .foregroundColor(Color(hex: template.category.colorHex))

                                Text(template.name)
                                    .font(.headline)
                            } else {
                                Text(building.templateId)
                                    .font(.headline)
                            }

                            Spacer()

                            Text("Lv.\(building.level)")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(ApocalypseTheme.primary.opacity(0.2))
                                .cornerRadius(4)
                        }

                        HStack {
                            Text("状态: \(building.status.displayName)")
                            Spacer()
                            if let coord = building.coordinate {
                                Text(String(format: "%.4f, %.4f", coord.latitude, coord.longitude))
                            }
                        }
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("我的建筑")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    refreshBuildings()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
        }
        .onAppear {
            refreshBuildings()
        }
    }

    private func refreshBuildings() {
        isLoading = true
        Task {
            try? await buildingManager.fetchAllPlayerBuildings()
            isLoading = false
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DeveloperToolsView()
    }
}
