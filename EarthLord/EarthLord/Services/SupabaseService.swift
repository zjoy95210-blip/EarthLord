//
//  SupabaseService.swift
//  EarthLord
//
//  Supabase 数据服务层
//

import Foundation
import Supabase
import Observation

// MARK: - Supabase Service
/// Supabase 数据操作服务
@MainActor
@Observable
final class SupabaseService {
    static let shared = SupabaseService()

    private init() {}

    // MARK: - Profile Operations

    /// 获取当前用户资料
    func getCurrentProfile() async throws -> Profile? {
        guard let userId = supabase.auth.currentUser?.id else {
            return nil
        }

        let profile: Profile = try await supabase
            .from("profiles")
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
            .value

        return profile
    }

    /// 获取指定用户资料
    func getProfile(userId: UUID) async throws -> Profile {
        let profile: Profile = try await supabase
            .from("profiles")
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
            .value

        return profile
    }

    /// 更新用户资料
    func updateProfile(userId: UUID, update: ProfileUpdate) async throws {
        try await supabase
            .from("profiles")
            .update(update)
            .eq("id", value: userId)
            .execute()
    }

    // MARK: - Territory Operations

    /// 获取用户的所有领地
    func getTerritories(userId: UUID) async throws -> [Territory] {
        let territories: [Territory] = try await supabase
            .from("territories")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value

        return territories
    }

    /// 获取所有领地（用于地图显示）
    func getAllTerritories() async throws -> [Territory] {
        let territories: [Territory] = try await supabase
            .from("territories")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value

        return territories
    }

    /// 创建新领地
    func createTerritory(_ territory: TerritoryInsert) async throws -> Territory {
        let newTerritory: Territory = try await supabase
            .from("territories")
            .insert(territory)
            .select()
            .single()
            .execute()
            .value

        return newTerritory
    }

    /// 更新领地
    func updateTerritory(id: UUID, name: String) async throws {
        try await supabase
            .from("territories")
            .update(["name": name])
            .eq("id", value: id)
            .execute()
    }

    /// 删除领地
    func deleteTerritory(id: UUID) async throws {
        try await supabase
            .from("territories")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - POI Operations

    /// 获取所有 POI
    func getAllPOIs() async throws -> [POI] {
        let pois: [POI] = try await supabase
            .from("pois")
            .select()
            .execute()
            .value

        return pois
    }

    /// 获取指定类型的 POI
    func getPOIs(type: POIType) async throws -> [POI] {
        let pois: [POI] = try await supabase
            .from("pois")
            .select()
            .eq("poi_type", value: type.rawValue)
            .execute()
            .value

        return pois
    }

    /// 获取用户发现的 POI
    func getDiscoveredPOIs(userId: UUID) async throws -> [POI] {
        let pois: [POI] = try await supabase
            .from("pois")
            .select()
            .eq("discovered_by", value: userId)
            .order("discovered_at", ascending: false)
            .execute()
            .value

        return pois
    }

    /// 创建新 POI
    func createPOI(_ poi: POIInsert) async throws -> POI {
        let newPOI: POI = try await supabase
            .from("pois")
            .insert(poi)
            .select()
            .single()
            .execute()
            .value

        return newPOI
    }

    /// 检查 POI 是否已存在
    func poiExists(id: String) async throws -> Bool {
        let count = try await supabase
            .from("pois")
            .select("id", head: true, count: .exact)
            .eq("id", value: id)
            .execute()
            .count

        return (count ?? 0) > 0
    }

    // MARK: - Connection Test

    /// 测试数据库连接
    func testConnection() async throws -> Bool {
        // 尝试查询 profiles 表来测试连接
        let _: [Profile] = try await supabase
            .from("profiles")
            .select()
            .limit(1)
            .execute()
            .value

        return true
    }
}

// MARK: - Auth Service Extension
extension SupabaseService {
    /// 获取当前登录用户 ID
    var currentUserId: UUID? {
        supabase.auth.currentUser?.id
    }

    /// 检查用户是否已登录
    var isAuthenticated: Bool {
        supabase.auth.currentUser != nil
    }
}

// MARK: - Item Definition Operations
extension SupabaseService {
    /// 获取所有物品定义
    func getAllItemDefinitions() async throws -> [DBItemDefinition] {
        let items: [DBItemDefinition] = try await supabase
            .from("item_definitions")
            .select()
            .execute()
            .value

        return items
    }

    /// 根据 ID 获取物品定义
    func getItemDefinition(id: String) async throws -> DBItemDefinition? {
        let items: [DBItemDefinition] = try await supabase
            .from("item_definitions")
            .select()
            .eq("id", value: id)
            .limit(1)
            .execute()
            .value

        return items.first
    }

    /// 根据稀有度获取物品定义
    func getItemDefinitions(rarity: DBItemRarity) async throws -> [DBItemDefinition] {
        let items: [DBItemDefinition] = try await supabase
            .from("item_definitions")
            .select()
            .eq("rarity", value: rarity.rawValue)
            .execute()
            .value

        return items
    }

    /// 根据分类获取物品定义
    func getItemDefinitions(category: DBItemCategory) async throws -> [DBItemDefinition] {
        let items: [DBItemDefinition] = try await supabase
            .from("item_definitions")
            .select()
            .eq("category", value: category.rawValue)
            .execute()
            .value

        return items
    }
}

// MARK: - Exploration Session Operations
extension SupabaseService {
    /// 创建探索记录
    func createExplorationSession(startLat: Double?, startLng: Double?) async throws -> ExplorationSession {
        guard let userId = currentUserId else {
            throw NSError(domain: "SupabaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "用户未登录"])
        }

        let insert = ExplorationSessionInsert(
            userId: userId,
            startTime: Date(),
            startLat: startLat,
            startLng: startLng,
            status: "active"
        )

        let session: ExplorationSession = try await supabase
            .from("exploration_sessions")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value

        return session
    }

    /// 更新探索记录（探索结束时调用）
    func updateExplorationSession(
        sessionId: UUID,
        endLat: Double?,
        endLng: Double?,
        totalDistance: Double,
        duration: Int,
        rewardTier: RewardTier,
        itemsRewarded: [RewardedItem]
    ) async throws {
        let update = ExplorationSessionUpdate(
            endTime: Date(),
            duration: duration,
            endLat: endLat,
            endLng: endLng,
            totalDistance: totalDistance,
            rewardTier: rewardTier.rawValue,
            itemsRewarded: itemsRewarded,
            status: "completed"
        )

        try await supabase
            .from("exploration_sessions")
            .update(update)
            .eq("id", value: sessionId)
            .execute()
    }

    /// 取消探索记录
    func cancelExplorationSession(sessionId: UUID) async throws {
        try await supabase
            .from("exploration_sessions")
            .update(["status": "cancelled", "end_time": ISO8601DateFormatter().string(from: Date())])
            .eq("id", value: sessionId)
            .execute()
    }

    /// 获取用户的探索记录
    func getExplorationSessions(userId: UUID, limit: Int = 20) async throws -> [ExplorationSession] {
        let sessions: [ExplorationSession] = try await supabase
            .from("exploration_sessions")
            .select()
            .eq("user_id", value: userId)
            .eq("status", value: "completed")
            .order("start_time", ascending: false)
            .limit(limit)
            .execute()
            .value

        return sessions
    }

    /// 获取用户的累计探索数据
    func getExplorationStats(userId: UUID) async throws -> (totalDistance: Double, totalDuration: Int, sessionCount: Int) {
        let sessions: [ExplorationSession] = try await supabase
            .from("exploration_sessions")
            .select()
            .eq("user_id", value: userId)
            .eq("status", value: "completed")
            .execute()
            .value

        let totalDistance = sessions.reduce(0.0) { $0 + $1.totalDistance }
        let totalDuration = sessions.reduce(0) { $0 + ($1.duration ?? 0) }
        return (totalDistance, totalDuration, sessions.count)
    }
}

// MARK: - Inventory Operations
extension SupabaseService {
    /// 获取用户背包物品
    func getInventoryItems(userId: UUID) async throws -> [DBInventoryItem] {
        let items: [DBInventoryItem] = try await supabase
            .from("inventory_items")
            .select()
            .eq("user_id", value: userId)
            .order("obtained_at", ascending: false)
            .execute()
            .value

        return items
    }

    /// 添加物品到背包（支持堆叠）
    func addItemToInventory(itemId: String, quantity: Int, quality: DBItemQuality?) async throws {
        guard let userId = currentUserId else {
            throw NSError(domain: "SupabaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "用户未登录"])
        }

        // 先查询是否已有相同物品和品质
        let qualityValue = quality?.rawValue ?? ""
        let existingItems: [DBInventoryItem] = try await supabase
            .from("inventory_items")
            .select()
            .eq("user_id", value: userId)
            .eq("item_id", value: itemId)
            .execute()
            .value

        // 找到品质相同的物品
        let matchingItem = existingItems.first { item in
            (item.quality?.rawValue ?? "") == qualityValue
        }

        if let existing = matchingItem {
            // 更新数量
            let newQuantity = existing.quantity + quantity
            try await supabase
                .from("inventory_items")
                .update(["quantity": newQuantity])
                .eq("id", value: existing.id)
                .execute()
        } else {
            // 插入新物品
            let insert = InventoryItemInsert(
                userId: userId,
                itemId: itemId,
                quantity: quantity,
                quality: quality?.rawValue
            )
            try await supabase
                .from("inventory_items")
                .insert(insert)
                .execute()
        }
    }

    /// 批量添加物品到背包
    func addItemsToInventory(items: [RewardedItem]) async throws {
        for item in items {
            try await addItemToInventory(
                itemId: item.itemId,
                quantity: item.quantity,
                quality: item.quality
            )
        }
    }

    /// 移除背包物品
    func removeItemFromInventory(inventoryItemId: UUID, quantity: Int) async throws {
        guard let userId = currentUserId else {
            throw NSError(domain: "SupabaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "用户未登录"])
        }

        // 先获取当前数量
        let items: [DBInventoryItem] = try await supabase
            .from("inventory_items")
            .select()
            .eq("id", value: inventoryItemId)
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value

        guard let item = items.first else {
            throw NSError(domain: "SupabaseService", code: 404, userInfo: [NSLocalizedDescriptionKey: "物品不存在"])
        }

        if item.quantity <= quantity {
            // 删除整条记录
            try await supabase
                .from("inventory_items")
                .delete()
                .eq("id", value: inventoryItemId)
                .execute()
        } else {
            // 减少数量
            let newQuantity = item.quantity - quantity
            try await supabase
                .from("inventory_items")
                .update(["quantity": newQuantity])
                .eq("id", value: inventoryItemId)
                .execute()
        }
    }

    /// 获取背包总重量
    func getInventoryWeight(userId: UUID) async throws -> Double {
        let items = try await getInventoryItems(userId: userId)
        let definitions = try await getAllItemDefinitions()

        var totalWeight = 0.0
        for item in items {
            if let def = definitions.first(where: { $0.id == item.itemId }) {
                totalWeight += def.weight * Double(item.quantity)
            }
        }
        return totalWeight
    }
}
