//
//  AIGeneratedItem.swift
//  EarthLord
//
//  AI 生成物品数据模型
//  定义 AI 生成物品的结构、请求和响应格式
//

import Foundation

// MARK: - AI 生成物品

/// AI 生成的物品（从 Edge Function 返回）
struct AIGeneratedItem: Codable, Identifiable, Sendable {
    var id: UUID { UUID() }

    let name: String              // 物品名称（AI 生成的独特名称）
    let category: String          // 物品分类
    let rarity: String            // 稀有度
    let story: String             // 背景故事（AI 生成）
    let quantity: Int             // 数量
    let quality: String?          // 品质（可选）
    let itemId: String            // 物品 ID

    enum CodingKeys: String, CodingKey {
        case name
        case category
        case rarity
        case story
        case quantity
        case quality
        case itemId = "item_id"
    }

    /// 转换分类为枚举
    var categoryEnum: DBItemCategory {
        DBItemCategory(rawValue: category) ?? .misc
    }

    /// 转换稀有度为枚举
    var rarityEnum: DBItemRarity {
        DBItemRarity(rawValue: rarity) ?? .common
    }

    /// 转换品质为枚举
    var qualityEnum: DBItemQuality? {
        guard let quality = quality else { return nil }
        return DBItemQuality(rawValue: quality)
    }
}

// MARK: - AI 生成请求

/// AI 生成请求参数
struct AIGenerateRequest: Codable, Sendable {
    let poiName: String           // POI 名称
    let poiCategory: String       // POI 分类
    let dangerLevel: Int          // 危险等级 1-5
    let itemCount: Int            // 请求生成的物品数量

    enum CodingKeys: String, CodingKey {
        case poiName = "poi_name"
        case poiCategory = "poi_category"
        case dangerLevel = "danger_level"
        case itemCount = "item_count"
    }
}

// MARK: - AI 生成响应

/// AI 生成响应
struct AIGenerateResponse: Codable, Sendable {
    let success: Bool
    let items: [AIGeneratedItem]?
    let error: String?
}

// MARK: - AI 奖励物品

/// AI 奖励物品（包含故事，用于 UI 展示）
struct AIRewardedItem: Codable, Identifiable, Sendable {
    let id: UUID
    let itemId: String            // 物品 ID
    let name: String              // AI 生成的名称
    let category: DBItemCategory
    let rarity: DBItemRarity
    let story: String             // AI 生成的故事
    let quantity: Int
    let quality: DBItemQuality?

    init(
        id: UUID = UUID(),
        itemId: String,
        name: String,
        category: DBItemCategory,
        rarity: DBItemRarity,
        story: String,
        quantity: Int,
        quality: DBItemQuality?
    ) {
        self.id = id
        self.itemId = itemId
        self.name = name
        self.category = category
        self.rarity = rarity
        self.story = story
        self.quantity = quantity
        self.quality = quality
    }

    /// 从 AIGeneratedItem 转换
    init(from item: AIGeneratedItem) {
        self.id = UUID()
        self.itemId = item.itemId
        self.name = item.name
        self.category = item.categoryEnum
        self.rarity = item.rarityEnum
        self.story = item.story
        self.quantity = item.quantity
        self.quality = item.qualityEnum
    }

    /// 转换为 RewardedItem（用于添加到背包）
    func toRewardedItem() -> RewardedItem {
        return RewardedItem(
            itemId: itemId,
            quantity: quantity,
            quality: quality
        )
    }
}
