//
//  InventoryManager.swift
//  EarthLord
//
//  背包管理器
//  负责管理玩家背包物品，与 Supabase 同步
//

import Foundation
import Observation
import Supabase

/// 背包管理器
@MainActor
@Observable
final class InventoryManager {

    // MARK: - Singleton
    static let shared = InventoryManager()

    // MARK: - Published Properties

    /// 背包物品列表
    var items: [DBInventoryItem] = []

    /// 物品定义缓存
    var itemDefinitions: [DBItemDefinition] = []

    /// 是否正在加载
    var isLoading = false

    /// 错误信息
    var errorMessage: String?

    /// 总重量
    var totalWeight: Double {
        var weight = 0.0
        for item in items {
            if let def = getItemDefinition(id: item.itemId) {
                weight += def.weight * Double(item.quantity)
            }
        }
        return weight
    }

    /// 物品种类数
    var itemTypeCount: Int {
        return items.count
    }

    /// 物品总数量
    var totalItemCount: Int {
        return items.reduce(0) { $0 + $1.quantity }
    }

    // MARK: - Constants

    /// 背包最大容量（kg）
    let maxCapacity: Double = 100.0

    // MARK: - Private Properties

    private let supabaseService = SupabaseService.shared

    // MARK: - Init

    private init() {}

    // MARK: - Public Methods

    /// 加载背包数据
    func loadInventory() async {
        guard let userId = supabaseService.currentUserId else {
            errorMessage = "用户未登录"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // 加载物品定义
            if itemDefinitions.isEmpty {
                itemDefinitions = try await supabaseService.getAllItemDefinitions()
                print("📦 [背包] 已加载 \(itemDefinitions.count) 个物品定义")
            }

            // 加载背包物品
            items = try await supabaseService.getInventoryItems(userId: userId)
            print("🎒 [背包] 已加载 \(items.count) 种物品")

            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "加载失败: \(error.localizedDescription)"
            print("❌ [背包] 加载失败: \(error.localizedDescription)")
        }
    }

    /// 刷新背包
    func refresh() async {
        await loadInventory()
    }

    /// 添加物品到背包
    func addItem(itemId: String, quantity: Int, quality: DBItemQuality?) async throws {
        try await supabaseService.addItemToInventory(
            itemId: itemId,
            quantity: quantity,
            quality: quality
        )
        // 刷新列表
        await loadInventory()
    }

    /// 使用物品
    func useItem(inventoryItemId: UUID, quantity: Int = 1) async throws {
        try await supabaseService.removeItemFromInventory(
            inventoryItemId: inventoryItemId,
            quantity: quantity
        )
        // 刷新列表
        await loadInventory()
        print("🔧 [背包] 使用物品成功")
    }

    /// 丢弃物品
    func discardItem(inventoryItemId: UUID, quantity: Int) async throws {
        try await supabaseService.removeItemFromInventory(
            inventoryItemId: inventoryItemId,
            quantity: quantity
        )
        // 刷新列表
        await loadInventory()
        print("🗑️ [背包] 丢弃物品成功")
    }

    /// 获取物品定义
    func getItemDefinition(id: String) -> DBItemDefinition? {
        return itemDefinitions.first { $0.id == id }
    }

    /// 按分类筛选物品
    func getItems(category: DBItemCategory) -> [DBInventoryItem] {
        return items.filter { item in
            if let def = getItemDefinition(id: item.itemId) {
                return def.category == category
            }
            return false
        }
    }

    /// 获取指定物品的总数量
    /// - Parameter itemId: 物品ID
    /// - Returns: 物品总数量
    func getItemCount(itemId: String) -> Int {
        return items
            .filter { $0.itemId == itemId }
            .reduce(0) { $0 + $1.quantity }
    }

    /// 搜索物品
    func searchItems(keyword: String) -> [DBInventoryItem] {
        if keyword.isEmpty {
            return items
        }
        return items.filter { item in
            if let def = getItemDefinition(id: item.itemId) {
                return def.name.localizedCaseInsensitiveContains(keyword)
            }
            return false
        }
    }

    /// 容量使用百分比
    var capacityPercentage: Double {
        return min(totalWeight / maxCapacity, 1.0)
    }

    /// 是否背包快满
    var isNearlyFull: Bool {
        return capacityPercentage > 0.9
    }

    /// 清空本地缓存
    func clearCache() {
        items = []
        itemDefinitions = []
        errorMessage = nil
    }

    // MARK: - Debug Methods

    #if DEBUG
    /// 添加测试资源（从物品定义中取材料类物品，各添加一定数量）
    func addTestResources() async -> Bool {
        // 确保物品定义已加载
        if itemDefinitions.isEmpty {
            await loadInventory()
        }

        // 筛选材料类物品
        let materialItems = itemDefinitions.filter { $0.category == .material }

        guard !materialItems.isEmpty else {
            print("❌ [测试] 没有找到材料类物品定义")
            return false
        }

        do {
            for item in materialItems {
                try await addItem(itemId: item.id, quantity: 50, quality: nil)
                print("✅ [测试] 添加 50 个 \(item.name)")
            }
            await loadInventory()
            print("✅ [测试] 测试资源添加完成")
            return true
        } catch {
            print("❌ [测试] 添加测试资源失败: \(error.localizedDescription)")
            return false
        }
    }

    /// 清空所有背包物品
    func clearAllItems() async -> Bool {
        guard let userId = supabaseService.currentUserId else {
            print("❌ [测试] 用户未登录")
            return false
        }

        do {
            try await supabase
                .from("inventory_items")
                .delete()
                .eq("user_id", value: userId)
                .execute()

            items = []
            print("✅ [测试] 已清空所有背包物品")
            return true
        } catch {
            print("❌ [测试] 清空背包失败: \(error.localizedDescription)")
            return false
        }
    }
    #endif
}

// MARK: - Item Display Helper
extension InventoryManager {

    /// 获取物品显示信息
    struct ItemDisplayInfo {
        let id: UUID
        let itemId: String
        let name: String
        let category: DBItemCategory
        let rarity: DBItemRarity
        let quantity: Int
        let quality: DBItemQuality?
        let weight: Double
        let totalWeight: Double
        let description: String?
        let hasQuality: Bool
    }

    /// 获取物品显示信息
    func getItemDisplayInfo(for item: DBInventoryItem) -> ItemDisplayInfo? {
        guard let def = getItemDefinition(id: item.itemId) else {
            return nil
        }

        return ItemDisplayInfo(
            id: item.id,
            itemId: item.itemId,
            name: def.name,
            category: def.category,
            rarity: def.rarity,
            quantity: item.quantity,
            quality: item.quality,
            weight: def.weight,
            totalWeight: def.weight * Double(item.quantity),
            description: def.description,
            hasQuality: def.hasQuality
        )
    }

    /// 获取所有物品的显示信息
    func getAllItemDisplayInfos() -> [ItemDisplayInfo] {
        return items.compactMap { getItemDisplayInfo(for: $0) }
    }
}
