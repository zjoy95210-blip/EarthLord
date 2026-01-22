//
//  BuildingManager.swift
//  EarthLord
//
//  建筑管理器
//  负责管理建筑模板、玩家建筑，与 Supabase 同步
//

import Foundation
import Observation
import Supabase

/// 建筑管理器
@MainActor
@Observable
final class BuildingManager {

    // MARK: - Singleton
    static let shared = BuildingManager()

    // MARK: - Properties

    /// 建筑模板列表（从 JSON 加载）
    var templates: [BuildingTemplate] = []

    /// 玩家建筑列表
    var buildings: [PlayerBuilding] = []

    /// 是否正在加载
    var isLoading = false

    /// 错误信息
    var errorMessage: String?

    // MARK: - Private Properties

    private let supabaseService = SupabaseService.shared
    private let inventoryManager = InventoryManager.shared

    // MARK: - Init

    private init() {
        print("🏗️ [建筑] BuildingManager 初始化完成")
    }

    // MARK: - Template Methods

    /// 从 JSON 加载建筑模板
    func loadTemplates() async throws {
        print("🏗️ [建筑] 开始加载建筑模板...")

        guard let url = Bundle.main.url(forResource: "building_templates", withExtension: "json") else {
            print("❌ [建筑] 找不到 building_templates.json 文件")
            throw BuildingError.jsonLoadFailed
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            templates = try decoder.decode([BuildingTemplate].self, from: data)

            print("✅ [建筑] 已加载 \(templates.count) 个建筑模板")
            for template in templates {
                print("  - \(template.name) (\(template.id))")
            }
        } catch {
            print("❌ [建筑] 模板解析失败: \(error)")
            throw BuildingError.jsonLoadFailed
        }
    }

    /// 获取指定 ID 的模板
    func getTemplate(id: String) -> BuildingTemplate? {
        return templates.first { $0.id == id }
    }

    /// 获取指定分类的模板列表
    func getTemplates(category: BuildingCategory) -> [BuildingTemplate] {
        return templates.filter { $0.category == category }
    }

    // MARK: - Build Check

    /// 检查是否可以建造指定建筑
    /// - Parameters:
    ///   - templateId: 建筑模板 ID
    ///   - territoryId: 领地 ID
    /// - Returns: 检查结果
    func canBuild(templateId: String, territoryId: UUID) async -> BuildCheckResult {
        // 检查用户登录
        guard supabaseService.currentUserId != nil else {
            return .failure(.notAuthenticated)
        }

        // 检查模板存在
        guard let template = getTemplate(id: templateId) else {
            return .failure(.templateNotFound)
        }

        // 检查建筑数量上限
        let existingCount = buildings.filter {
            $0.territoryId == territoryId && $0.templateId == templateId
        }.count

        if existingCount >= template.maxPerTerritory {
            return .failure(.maxBuildingsReached)
        }

        // 检查材料
        var missingMaterials: [MissingMaterial] = []

        for required in template.requiredMaterials {
            // 查找背包中的该物品
            let ownedQuantity = inventoryManager.items
                .filter { $0.itemId == required.itemId }
                .reduce(0) { $0 + $1.quantity }

            if ownedQuantity < required.quantity {
                let itemName = inventoryManager.getItemDefinition(id: required.itemId)?.name ?? required.itemId
                missingMaterials.append(MissingMaterial(
                    itemId: required.itemId,
                    itemName: itemName,
                    required: required.quantity,
                    owned: ownedQuantity,
                    shortage: required.quantity - ownedQuantity
                ))
            }
        }

        if !missingMaterials.isEmpty {
            return .failure(.insufficientMaterials, missingMaterials: missingMaterials)
        }

        return .success()
    }

    // MARK: - Construction Methods

    /// 开始建造建筑
    /// - Parameters:
    ///   - templateId: 建筑模板 ID
    ///   - territoryId: 领地 ID
    /// - Returns: 新建的建筑
    func startConstruction(templateId: String, territoryId: UUID) async throws -> PlayerBuilding {
        // 先检查是否可以建造
        let checkResult = await canBuild(templateId: templateId, territoryId: territoryId)
        if !checkResult.canBuild {
            throw checkResult.error ?? BuildingError.insufficientMaterials
        }

        guard let userId = supabaseService.currentUserId else {
            throw BuildingError.notAuthenticated
        }

        guard let template = getTemplate(id: templateId) else {
            throw BuildingError.templateNotFound
        }

        // 扣除材料
        for required in template.requiredMaterials {
            // 找到背包中对应的物品并扣除
            let matchingItems = inventoryManager.items.filter { $0.itemId == required.itemId }
            var remainingToDeduct = required.quantity

            for item in matchingItems {
                if remainingToDeduct <= 0 { break }

                let deductAmount = min(item.quantity, remainingToDeduct)
                try await inventoryManager.useItem(inventoryItemId: item.id, quantity: deductAmount)
                remainingToDeduct -= deductAmount
            }
        }

        // 创建建筑记录
        let insert = PlayerBuildingInsert(
            userId: userId,
            territoryId: territoryId,
            templateId: templateId,
            level: 1,
            status: BuildingStatus.constructing.rawValue,
            startedAt: Date()
        )

        let building: PlayerBuilding = try await supabase
            .from("player_buildings")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value

        // 添加到本地列表
        buildings.append(building)

        print("🏗️ [建筑] 开始建造: \(template.name)")
        return building
    }

    /// 完成建筑建造
    /// - Parameter buildingId: 建筑 ID
    func completeConstruction(buildingId: UUID) async throws {
        guard let index = buildings.firstIndex(where: { $0.id == buildingId }) else {
            throw BuildingError.buildingNotFound
        }

        let building = buildings[index]

        // 检查是否确实建造完成
        if let template = getTemplate(id: building.templateId) {
            if !building.isConstructionComplete(buildTime: template.buildTime) {
                print("⏳ [建筑] 建造尚未完成")
                return
            }
        }

        // 更新数据库
        let update = PlayerBuildingUpdate(
            level: nil,
            status: BuildingStatus.active.rawValue,
            completedAt: Date()
        )

        try await supabase
            .from("player_buildings")
            .update(update)
            .eq("id", value: buildingId)
            .execute()

        // 更新本地状态
        buildings[index].status = .active
        buildings[index].completedAt = Date()

        if let template = getTemplate(id: building.templateId) {
            print("✅ [建筑] 建造完成: \(template.name)")
        }
    }

    /// 升级建筑
    /// - Parameter buildingId: 建筑 ID
    func upgradeBuilding(buildingId: UUID) async throws {
        guard let index = buildings.firstIndex(where: { $0.id == buildingId }) else {
            throw BuildingError.buildingNotFound
        }

        let building = buildings[index]

        // 检查建筑状态必须为 active 才能升级
        guard building.status == .active else {
            print("⚠️ [建筑] 建筑未完成，无法升级")
            throw BuildingError.invalidStatus
        }

        guard let template = getTemplate(id: building.templateId) else {
            throw BuildingError.templateNotFound
        }

        // 检查是否已达最大等级
        if building.level >= template.maxLevel {
            print("⚠️ [建筑] 已达最大等级")
            return
        }

        // TODO: 检查升级所需材料（未来扩展）

        let newLevel = building.level + 1

        // 更新数据库
        let update = PlayerBuildingUpdate(
            level: newLevel,
            status: nil,
            completedAt: nil
        )

        try await supabase
            .from("player_buildings")
            .update(update)
            .eq("id", value: buildingId)
            .execute()

        // 更新本地状态
        buildings[index].level = newLevel

        print("⬆️ [建筑] 升级完成: \(template.name) Lv.\(newLevel)")
    }

    // MARK: - Fetch Methods

    /// 获取指定领地的建筑
    /// - Parameter territoryId: 领地 ID
    func fetchPlayerBuildings(territoryId: UUID) async throws {
        guard let userId = supabaseService.currentUserId else {
            throw BuildingError.notAuthenticated
        }

        isLoading = true
        errorMessage = nil

        do {
            let fetchedBuildings: [PlayerBuilding] = try await supabase
                .from("player_buildings")
                .select()
                .eq("user_id", value: userId)
                .eq("territory_id", value: territoryId)
                .order("created_at", ascending: false)
                .execute()
                .value

            // 更新本地列表（保留其他领地的建筑）
            buildings.removeAll { $0.territoryId == territoryId }
            buildings.append(contentsOf: fetchedBuildings)

            isLoading = false
            print("🏗️ [建筑] 已加载领地建筑: \(fetchedBuildings.count) 个")
        } catch {
            isLoading = false
            errorMessage = "加载建筑失败: \(error.localizedDescription)"
            print("❌ [建筑] 加载失败: \(error)")
            throw error
        }
    }

    /// 获取用户的所有建筑
    func fetchAllPlayerBuildings() async throws {
        guard let userId = supabaseService.currentUserId else {
            throw BuildingError.notAuthenticated
        }

        isLoading = true
        errorMessage = nil

        do {
            buildings = try await supabase
                .from("player_buildings")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
                .value

            isLoading = false
            print("🏗️ [建筑] 已加载所有建筑: \(buildings.count) 个")
        } catch {
            isLoading = false
            errorMessage = "加载建筑失败: \(error.localizedDescription)"
            print("❌ [建筑] 加载失败: \(error)")
            throw error
        }
    }

    /// 删除建筑
    /// - Parameter buildingId: 建筑 ID
    func deleteBuilding(buildingId: UUID) async throws {
        guard supabaseService.currentUserId != nil else {
            throw BuildingError.notAuthenticated
        }

        try await supabase
            .from("player_buildings")
            .delete()
            .eq("id", value: buildingId)
            .execute()

        // 从本地列表移除
        buildings.removeAll { $0.id == buildingId }

        print("🗑️ [建筑] 已删除建筑")
    }

    // MARK: - Helper Methods

    /// 获取指定领地的建筑数量
    /// - Parameter territoryId: 领地 ID
    /// - Returns: 建筑数量
    func getBuildingCount(territoryId: UUID) -> Int {
        return buildings.filter { $0.territoryId == territoryId }.count
    }

    /// 获取指定领地中指定模板的建筑数量
    /// - Parameters:
    ///   - templateId: 模板 ID
    ///   - territoryId: 领地 ID
    /// - Returns: 建筑数量
    func getBuildingCount(templateId: String, territoryId: UUID) -> Int {
        return buildings.filter {
            $0.territoryId == territoryId && $0.templateId == templateId
        }.count
    }

    /// 获取指定领地的建筑列表
    /// - Parameter territoryId: 领地 ID
    /// - Returns: 建筑列表
    func getBuildings(territoryId: UUID) -> [PlayerBuilding] {
        return buildings.filter { $0.territoryId == territoryId }
    }

    /// 检查并完成所有已完工的建筑
    func checkAndCompleteBuildings() async {
        for building in buildings where building.status == .constructing {
            if let template = getTemplate(id: building.templateId) {
                if building.isConstructionComplete(buildTime: template.buildTime) {
                    do {
                        try await completeConstruction(buildingId: building.id)
                    } catch {
                        print("❌ [建筑] 自动完成失败: \(error)")
                    }
                }
            }
        }
    }

    /// 清空本地缓存
    func clearCache() {
        buildings = []
        errorMessage = nil
    }
}

// MARK: - Building Display Helper
extension BuildingManager {

    /// 建筑显示信息
    struct BuildingDisplayInfo {
        let id: UUID
        let templateId: String
        let name: String
        let description: String
        let category: BuildingCategory
        let level: Int
        let maxLevel: Int
        let status: BuildingStatus
        let iconName: String
        let remainingTime: Int      // 剩余建造时间（秒）
        let formattedRemainingTime: String
    }

    /// 获取建筑显示信息
    func getBuildingDisplayInfo(for building: PlayerBuilding) -> BuildingDisplayInfo? {
        guard let template = getTemplate(id: building.templateId) else {
            return nil
        }

        let remaining = building.remainingBuildTime(buildTime: template.buildTime)

        return BuildingDisplayInfo(
            id: building.id,
            templateId: building.templateId,
            name: template.name,
            description: template.description,
            category: template.category,
            level: building.level,
            maxLevel: template.maxLevel,
            status: building.status,
            iconName: template.iconName,
            remainingTime: remaining,
            formattedRemainingTime: building.formattedRemainingTime(buildTime: template.buildTime)
        )
    }

    /// 获取所有建筑的显示信息
    func getAllBuildingDisplayInfos() -> [BuildingDisplayInfo] {
        return buildings.compactMap { getBuildingDisplayInfo(for: $0) }
    }

    /// 获取指定领地建筑的显示信息
    func getBuildingDisplayInfos(territoryId: UUID) -> [BuildingDisplayInfo] {
        return getBuildings(territoryId: territoryId).compactMap { getBuildingDisplayInfo(for: $0) }
    }
}
