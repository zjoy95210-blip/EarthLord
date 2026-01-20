//
//  AIItemGenerator.swift
//  EarthLord
//
//  AI 物品生成服务
//  调用 Supabase Edge Function 生成具有独特名称和故事的物品
//

import Foundation
import Supabase
import Functions

/// AI 物品生成错误
enum AIGeneratorError: LocalizedError {
    case networkError(String)
    case apiError(String)
    case parseError(String)
    case noItemsGenerated

    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "网络错误: \(message)"
        case .apiError(let message):
            return "API 错误: \(message)"
        case .parseError(let message):
            return "解析错误: \(message)"
        case .noItemsGenerated:
            return "未生成任何物品"
        }
    }
}

/// AI 物品生成服务
@MainActor
final class AIItemGenerator {

    // MARK: - Singleton

    static let shared = AIItemGenerator()

    // MARK: - Private Properties

    /// 本地备用物品池（降级方案）
    private var fallbackItems: [DBItemDefinition] = []

    /// 是否已加载备用物品
    private var fallbackLoaded = false

    // MARK: - Init

    private init() {}

    // MARK: - Public Methods

    /// 生成 AI 物品
    /// - Parameters:
    ///   - poi: 搜刮的 POI
    ///   - itemCount: 物品数量（默认 1-3 个）
    /// - Returns: 生成的物品列表
    func generateItems(for poi: ScavengePOI, itemCount: Int? = nil) async throws -> [AIRewardedItem] {
        let count = itemCount ?? Int.random(in: 1...3)

        print("🤖 [AI生成] 开始为 \(poi.name) 生成 \(count) 个物品...")
        print("🤖 [AI生成] 危险等级: \(poi.dangerLevel.rawValue) (\(poi.dangerLevel.displayName))")

        do {
            // 调用 Edge Function
            let items = try await callGenerateFunction(poi: poi, itemCount: count)
            print("✅ [AI生成] 成功生成 \(items.count) 个 AI 物品")
            return items
        } catch {
            print("⚠️ [AI生成] AI 生成失败，使用降级方案: \(error.localizedDescription)")
            // 降级：使用本地预设物品
            return try await generateFallbackItems(poi: poi, count: count)
        }
    }

    /// 预加载降级物品池
    func preloadFallback() async {
        guard !fallbackLoaded else { return }

        do {
            fallbackItems = try await SupabaseService.shared.getAllItemDefinitions()
            fallbackLoaded = true
            print("📦 [AI生成] 已加载 \(fallbackItems.count) 个备用物品定义")
        } catch {
            print("⚠️ [AI生成] 加载备用物品失败: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Methods

    /// 调用 Edge Function 生成物品
    private func callGenerateFunction(poi: ScavengePOI, itemCount: Int) async throws -> [AIRewardedItem] {
        // 构建请求参数
        let request = AIGenerateRequest(
            poiName: poi.name,
            poiCategory: poi.category.rawValue,
            dangerLevel: poi.dangerLevel.intValue,
            itemCount: itemCount
        )

        // 调用 Edge Function
        let response: AIGenerateResponse = try await supabase.functions.invoke(
            "generate-ai-item",
            options: .init(body: request)
        )

        // 检查响应
        guard response.success else {
            throw AIGeneratorError.apiError(response.error ?? "未知错误")
        }

        guard let items = response.items, !items.isEmpty else {
            throw AIGeneratorError.noItemsGenerated
        }

        // 转换为 AIRewardedItem
        return items.map { AIRewardedItem(from: $0) }
    }

    /// 降级方案：使用本地预设物品生成
    private func generateFallbackItems(poi: ScavengePOI, count: Int) async throws -> [AIRewardedItem] {
        // 确保已加载备用物品
        await preloadFallback()

        guard !fallbackItems.isEmpty else {
            throw AIGeneratorError.parseError("没有可用的备用物品")
        }

        var results: [AIRewardedItem] = []

        for _ in 0..<count {
            // 根据 POI 分类选择物品分类
            let category = selectCategory(for: poi.category)

            // 根据危险值选择稀有度
            let rarity = rollRarity(dangerLevel: poi.dangerLevel)

            // 从备用物品池中选择
            let eligibleItems = fallbackItems.filter {
                $0.category == category || $0.rarity == rarity
            }

            if let item = eligibleItems.randomElement() ?? fallbackItems.randomElement() {
                let quality: DBItemQuality? = item.hasQuality ? DBItemQuality.random() : nil
                let quantity = item.rarity == .common ? Int.random(in: 1...3) : 1

                results.append(AIRewardedItem(
                    itemId: item.id,
                    name: item.name,
                    category: item.category,
                    rarity: item.rarity,
                    story: item.description ?? "在末世中找到的物资。",
                    quantity: quantity,
                    quality: quality
                ))
            }
        }

        print("📦 [AI生成] 降级生成了 \(results.count) 个物品")
        return results
    }

    /// 根据 POI 分类选择物品分类
    private func selectCategory(for poiCategory: ScavengePOICategory) -> DBItemCategory {
        let weights = poiCategory.rewardTier.categoryWeights
        let total = weights.reduce(0.0) { $0 + $1.1 }
        var random = Double.random(in: 0..<total)

        for (category, weight) in weights {
            random -= weight
            if random <= 0 {
                return category
            }
        }

        return .misc
    }

    /// 根据危险值随机稀有度
    private func rollRarity(dangerLevel: DangerLevel) -> DBItemRarity {
        let roll = Double.random(in: 0..<100)

        switch dangerLevel {
        case .safe, .low, .medium:  // 0-2
            // 普通 70%, 优秀 25%, 稀有 5%
            if roll < 70 { return .common }
            else if roll < 95 { return .uncommon }
            else { return .rare }

        case .moderate:  // 3
            // 普通 50%, 优秀 30%, 稀有 15%, 史诗 5%
            if roll < 50 { return .common }
            else if roll < 80 { return .uncommon }
            else if roll < 95 { return .rare }
            else { return .epic }

        case .high:  // 4
            // 优秀 40%, 稀有 35%, 史诗 20%, 传奇 5%
            if roll < 40 { return .uncommon }
            else if roll < 75 { return .rare }
            else if roll < 95 { return .epic }
            else { return .legendary }

        case .extreme:  // 5
            // 稀有 30%, 史诗 40%, 传奇 30%
            if roll < 30 { return .rare }
            else if roll < 70 { return .epic }
            else { return .legendary }
        }
    }
}
