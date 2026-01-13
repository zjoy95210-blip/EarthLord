//
//  RewardGenerator.swift
//  EarthLord
//
//  奖励生成器
//  根据探索距离计算奖励等级并生成随机物品
//

import Foundation

/// 奖励生成器
@MainActor
final class RewardGenerator {

    // MARK: - Singleton
    static let shared = RewardGenerator()

    // MARK: - Private Properties

    /// 缓存的物品定义
    private var itemDefinitionsCache: [DBItemDefinition] = []

    /// 缓存是否已加载
    private var isCacheLoaded = false

    /// Supabase 服务
    private let supabaseService = SupabaseService.shared

    // MARK: - Init

    private init() {}

    // MARK: - Public Methods

    /// 生成奖励物品
    func generateRewards(tier: RewardTier) async throws -> [RewardedItem] {
        guard tier != .none else {
            return []
        }

        // 确保缓存已加载
        try await loadCacheIfNeeded()

        let itemCount = tier.itemCount
        var rewards: [RewardedItem] = []

        for _ in 0..<itemCount {
            // 根据等级确定稀有度
            let rarity = rollRarity(tier: tier)

            // 从对应稀有度的物品池中随机选择
            if let item = selectRandomItem(rarity: rarity) {
                // 确定品质（如果物品有品质属性）
                let quality: DBItemQuality? = item.hasQuality ? DBItemQuality.random() : nil

                // 确定数量（普通物品可能给多个）
                let quantity = calculateQuantity(item: item, tier: tier)

                let rewardItem = RewardedItem(
                    itemId: item.id,
                    quantity: quantity,
                    quality: quality
                )
                rewards.append(rewardItem)

                print("🎁 [奖励] 生成物品: \(item.name) x\(quantity), 稀有度: \(rarity.displayName), 品质: \(quality?.displayName ?? "无")")
            }
        }

        return rewards
    }

    /// 预加载物品定义缓存
    func preloadCache() async {
        do {
            try await loadCacheIfNeeded()
        } catch {
            print("⚠️ [奖励] 预加载缓存失败: \(error.localizedDescription)")
        }
    }

    /// 清除缓存
    func clearCache() {
        itemDefinitionsCache = []
        isCacheLoaded = false
    }

    // MARK: - Private Methods

    /// 加载物品定义缓存
    private func loadCacheIfNeeded() async throws {
        guard !isCacheLoaded else { return }

        itemDefinitionsCache = try await supabaseService.getAllItemDefinitions()
        isCacheLoaded = true
        print("📦 [奖励] 已加载 \(itemDefinitionsCache.count) 个物品定义")
    }

    /// 根据等级掷骰子决定稀有度
    private func rollRarity(tier: RewardTier) -> DBItemRarity {
        let roll = Double.random(in: 0..<100)

        switch tier {
        case .none:
            return .common

        case .bronze:
            // 普通 90%, 稀有 10%, 史诗 0%
            if roll < 90 {
                return .common
            } else {
                return .rare
            }

        case .silver:
            // 普通 70%, 稀有 25%, 史诗 5%
            if roll < 70 {
                return .common
            } else if roll < 95 {
                return .rare
            } else {
                return .epic
            }

        case .gold:
            // 普通 50%, 稀有 35%, 史诗 15%
            if roll < 50 {
                return .common
            } else if roll < 85 {
                return .rare
            } else {
                return .epic
            }

        case .diamond:
            // 普通 30%, 稀有 40%, 史诗 30%
            if roll < 30 {
                return .common
            } else if roll < 70 {
                return .rare
            } else {
                return .epic
            }
        }
    }

    /// 从物品池中随机选择一个物品
    private func selectRandomItem(rarity: DBItemRarity) -> DBItemDefinition? {
        // 根据稀有度映射到可选稀有度列表
        // common -> common, uncommon
        // rare -> uncommon, rare
        // epic -> rare, epic, legendary

        let availableRarities: [DBItemRarity]
        switch rarity {
        case .common:
            availableRarities = [.common, .uncommon]
        case .uncommon:
            availableRarities = [.uncommon]
        case .rare:
            availableRarities = [.uncommon, .rare]
        case .epic:
            availableRarities = [.rare, .epic, .legendary]
        case .legendary:
            availableRarities = [.epic, .legendary]
        }

        // 过滤符合条件的物品
        let eligibleItems = itemDefinitionsCache.filter { item in
            availableRarities.contains(item.rarity)
        }

        // 随机选择一个
        return eligibleItems.randomElement()
    }

    /// 计算物品数量
    private func calculateQuantity(item: DBItemDefinition, tier: RewardTier) -> Int {
        // 稀有度越低，数量可能越多
        // 等级越高，数量可能越多

        let baseQuantity: Int
        switch item.rarity {
        case .common:
            baseQuantity = Int.random(in: 1...3)
        case .uncommon:
            baseQuantity = Int.random(in: 1...2)
        case .rare, .epic, .legendary:
            baseQuantity = 1
        }

        // 钻石级有额外奖励
        let bonus = tier == .diamond ? 1 : 0

        // 不超过最大堆叠数
        return min(baseQuantity + bonus, item.maxStack)
    }

    /// 获取物品定义（供外部使用）
    func getItemDefinition(id: String) -> DBItemDefinition? {
        return itemDefinitionsCache.first { $0.id == id }
    }

    /// 获取所有物品定义（供外部使用）
    func getAllItemDefinitions() -> [DBItemDefinition] {
        return itemDefinitionsCache
    }
}
