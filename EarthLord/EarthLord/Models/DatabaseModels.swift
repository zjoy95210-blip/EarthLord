//
//  DatabaseModels.swift
//  EarthLord
//
//  数据库模型定义 - 对应 Supabase 表结构
//

import Foundation
import CoreLocation

// MARK: - Profile (用户资料)
/// 对应 profiles 表
struct Profile: Codable, Identifiable, Sendable {
    let id: UUID
    var username: String?
    var avatarUrl: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
    }
}

// MARK: - Territory (领地)
/// 对应 territories 表
struct Territory: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    var name: String?                    // ⚠️ 可选，数据库允许为空
    var path: [[String: Double]]         // 格式：[{"lat": x, "lon": y}]
    var area: Double                     // 面积（平方米）
    let pointCount: Int?                 // 路径点数量
    let isActive: Bool?                  // 是否有效
    let startedAt: Date?                 // 开始圈地时间
    let completedAt: Date?               // 完成圈地时间
    let createdAt: Date?                 // 创建时间

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case path
        case area
        case pointCount = "point_count"
        case isActive = "is_active"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case createdAt = "created_at"
    }

    /// 将 path 转换为 CLLocationCoordinate2D 数组
    func toCoordinates() -> [CLLocationCoordinate2D] {
        return path.compactMap { point in
            guard let lat = point["lat"], let lon = point["lon"] else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }

    // MARK: - 辅助属性

    /// 格式化面积显示
    var formattedArea: String {
        if area >= 1_000_000 {
            return String(format: "%.2f km²", area / 1_000_000)
        } else if area >= 10_000 {
            return String(format: "%.2f 万m²", area / 10_000)
        } else {
            return String(format: "%.0f m²", area)
        }
    }

    /// 显示名称（如果没有名称则显示面积）
    var displayName: String {
        if let name = name, !name.isEmpty {
            return name
        }
        // 未命名时显示 "领地 + 面积"
        if area >= 1_000_000 {
            return String(format: "领地 %.2fkm²", area / 1_000_000)
        } else if area >= 10_000 {
            return String(format: "领地 %.2f万m²", area / 10_000)
        } else {
            return String(format: "领地 %.0fm²", area)
        }
    }

    /// 格式化创建时间
    var formattedCreatedAt: String {
        guard let date = createdAt else { return "未知时间" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }

    /// 格式化圈地时长
    var formattedDuration: String {
        guard let start = startedAt, let end = completedAt else {
            return "未知"
        }
        let duration = end.timeIntervalSince(start)
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return "\(minutes)分\(seconds)秒"
        } else {
            return "\(seconds)秒"
        }
    }
}

// MARK: - Coordinate (坐标点)
/// 领地路径中的坐标点
struct Coordinate: Codable, Sendable, Equatable {
    let latitude: Double
    let longitude: Double

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

// MARK: - POI (兴趣点)
/// 对应 pois 表
struct POI: Codable, Identifiable, Sendable {
    let id: String          // 外部 ID (TEXT)
    let poiType: POIType
    var name: String
    let latitude: Double
    let longitude: Double
    var discoveredBy: UUID?
    let discoveredAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case poiType = "poi_type"
        case name
        case latitude
        case longitude
        case discoveredBy = "discovered_by"
        case discoveredAt = "discovered_at"
    }
}

// MARK: - POI Type (兴趣点类型)
/// POI 类型枚举
enum POIType: String, Codable, CaseIterable, Sendable {
    case hospital = "hospital"          // 医院
    case supermarket = "supermarket"    // 超市
    case factory = "factory"            // 工厂
    case gasStation = "gas_station"     // 加油站
    case school = "school"              // 学校
    case restaurant = "restaurant"      // 餐厅
    case shelter = "shelter"            // 避难所
    case waterSource = "water_source"   // 水源
    case powerPlant = "power_plant"     // 发电厂
    case military = "military"          // 军事基地
    case unknown = "unknown"            // 未知

    var displayName: String {
        switch self {
        case .hospital: return "医院"
        case .supermarket: return "超市"
        case .factory: return "工厂"
        case .gasStation: return "加油站"
        case .school: return "学校"
        case .restaurant: return "餐厅"
        case .shelter: return "避难所"
        case .waterSource: return "水源"
        case .powerPlant: return "发电厂"
        case .military: return "军事基地"
        case .unknown: return "未知"
        }
    }

    var iconName: String {
        switch self {
        case .hospital: return "cross.case.fill"
        case .supermarket: return "cart.fill"
        case .factory: return "building.2.fill"
        case .gasStation: return "fuelpump.fill"
        case .school: return "graduationcap.fill"
        case .restaurant: return "fork.knife"
        case .shelter: return "house.fill"
        case .waterSource: return "drop.fill"
        case .powerPlant: return "bolt.fill"
        case .military: return "shield.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }
}

// MARK: - Insert Models (用于插入数据)

/// 创建新领地时使用的模型
struct TerritoryInsert: Codable, Sendable {
    let userId: UUID
    let path: [[String: Double]]         // [{"lat": x, "lon": y}]
    let polygon: String                   // WKT 格式
    let bboxMinLat: Double
    let bboxMaxLat: Double
    let bboxMinLon: Double
    let bboxMaxLon: Double
    let area: Double
    let pointCount: Int
    let startedAt: String                 // ISO8601 格式
    let completedAt: String               // ISO8601 格式
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case path
        case polygon
        case bboxMinLat = "bbox_min_lat"
        case bboxMaxLat = "bbox_max_lat"
        case bboxMinLon = "bbox_min_lon"
        case bboxMaxLon = "bbox_max_lon"
        case area
        case pointCount = "point_count"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case isActive = "is_active"
    }
}

/// 创建新 POI 时使用的模型
struct POIInsert: Codable, Sendable {
    let id: String
    let poiType: String
    let name: String
    let latitude: Double
    let longitude: Double
    let discoveredBy: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case poiType = "poi_type"
        case name
        case latitude
        case longitude
        case discoveredBy = "discovered_by"
    }
}

/// 创建/更新用户资料时使用的模型
struct ProfileUpdate: Codable, Sendable {
    let username: String?
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case username
        case avatarUrl = "avatar_url"
    }
}

// MARK: - 探索奖励相关模型

/// 奖励等级枚举
enum RewardTier: String, Codable, CaseIterable, Sendable {
    case none = "none"           // 无奖励 (< 200米)
    case bronze = "bronze"       // 铜级 (200-500米)
    case silver = "silver"       // 银级 (500-1000米)
    case gold = "gold"           // 金级 (1000-2000米)
    case diamond = "diamond"     // 钻石级 (> 2000米)

    /// 显示名称
    var displayName: String {
        switch self {
        case .none: return "无奖励"
        case .bronze: return "铜级"
        case .silver: return "银级"
        case .gold: return "金级"
        case .diamond: return "钻石级"
        }
    }

    /// 等级图标
    var iconName: String {
        switch self {
        case .none: return "xmark.circle"
        case .bronze: return "medal.fill"
        case .silver: return "medal.fill"
        case .gold: return "medal.fill"
        case .diamond: return "diamond.fill"
        }
    }

    /// 等级颜色（十六进制）
    var colorHex: String {
        switch self {
        case .none: return "9E9E9E"      // 灰色
        case .bronze: return "CD7F32"    // 铜色
        case .silver: return "C0C0C0"    // 银色
        case .gold: return "FFD700"      // 金色
        case .diamond: return "B9F2FF"   // 钻石蓝
        }
    }

    /// 物品数量
    var itemCount: Int {
        switch self {
        case .none: return 0
        case .bronze: return 1
        case .silver: return 2
        case .gold: return 3
        case .diamond: return 5
        }
    }

    /// 根据距离计算等级
    static func fromDistance(_ meters: Double) -> RewardTier {
        switch meters {
        case ..<200: return .none
        case 200..<500: return .bronze
        case 500..<1000: return .silver
        case 1000..<2000: return .gold
        default: return .diamond
        }
    }

    /// 下一等级需要的距离阈值
    var nextTierThreshold: Double {
        switch self {
        case .none: return 200
        case .bronze: return 500
        case .silver: return 1000
        case .gold: return 2000
        case .diamond: return Double.infinity // 已是最高等级
        }
    }

    /// 下一等级
    var nextTier: RewardTier? {
        switch self {
        case .none: return .bronze
        case .bronze: return .silver
        case .silver: return .gold
        case .gold: return .diamond
        case .diamond: return nil // 已是最高等级
        }
    }

    /// 计算距离下一等级还差多少米
    static func distanceToNextTier(currentDistance: Double) -> Double {
        let currentTier = fromDistance(currentDistance)
        let threshold = currentTier.nextTierThreshold
        if threshold == Double.infinity {
            return 0 // 已是最高等级
        }
        return max(0, threshold - currentDistance)
    }
}

/// 物品分类枚举（数据库版本）
enum DBItemCategory: String, Codable, CaseIterable, Sendable {
    case water = "water"
    case food = "food"
    case medical = "medical"
    case material = "material"
    case tool = "tool"
    case weapon = "weapon"
    case clothing = "clothing"
    case misc = "misc"

    var displayName: String {
        switch self {
        case .water: return "水类"
        case .food: return "食物"
        case .medical: return "医疗"
        case .material: return "材料"
        case .tool: return "工具"
        case .weapon: return "武器"
        case .clothing: return "服装"
        case .misc: return "杂项"
        }
    }

    var iconName: String {
        switch self {
        case .water: return "drop.fill"
        case .food: return "fork.knife"
        case .medical: return "cross.case.fill"
        case .material: return "shippingbox.fill"
        case .tool: return "wrench.and.screwdriver.fill"
        case .weapon: return "hammer.fill"
        case .clothing: return "tshirt.fill"
        case .misc: return "questionmark.circle.fill"
        }
    }
}

/// 物品稀有度枚举（数据库版本）
enum DBItemRarity: String, Codable, CaseIterable, Sendable {
    case common = "common"
    case uncommon = "uncommon"
    case rare = "rare"
    case epic = "epic"
    case legendary = "legendary"

    var displayName: String {
        switch self {
        case .common: return "普通"
        case .uncommon: return "优秀"
        case .rare: return "稀有"
        case .epic: return "史诗"
        case .legendary: return "传说"
        }
    }

    var colorHex: String {
        switch self {
        case .common: return "9E9E9E"
        case .uncommon: return "4CAF50"
        case .rare: return "2196F3"
        case .epic: return "9C27B0"
        case .legendary: return "FF9800"
        }
    }
}

/// 物品品质枚举（数据库版本）
enum DBItemQuality: String, Codable, Sendable {
    case broken = "broken"
    case worn = "worn"
    case normal = "normal"
    case fine = "fine"
    case pristine = "pristine"

    var displayName: String {
        switch self {
        case .broken: return "破损"
        case .worn: return "磨损"
        case .normal: return "正常"
        case .fine: return "精良"
        case .pristine: return "完美"
        }
    }

    var effectMultiplier: Double {
        switch self {
        case .broken: return 0.5
        case .worn: return 0.75
        case .normal: return 1.0
        case .fine: return 1.1
        case .pristine: return 1.25
        }
    }

    /// 随机生成一个品质（带权重）
    static func random() -> DBItemQuality {
        let roll = Double.random(in: 0..<100)
        switch roll {
        case ..<5: return .pristine    // 5%
        case ..<15: return .fine       // 10%
        case ..<55: return .normal     // 40%
        case ..<80: return .worn       // 25%
        default: return .broken        // 20%
        }
    }
}

// MARK: - ItemDefinition (物品定义)
/// 对应 item_definitions 表
struct DBItemDefinition: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let category: DBItemCategory
    let weight: Double
    let rarity: DBItemRarity
    let maxStack: Int
    let description: String?
    let hasQuality: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case category
        case weight
        case rarity
        case maxStack = "max_stack"
        case description
        case hasQuality = "has_quality"
    }
}

// MARK: - ExplorationSession (探索记录)
/// 对应 exploration_sessions 表
struct ExplorationSession: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let startTime: Date
    var endTime: Date?
    var duration: Int?
    let startLat: Double?
    let startLng: Double?
    var endLat: Double?
    var endLng: Double?
    var totalDistance: Double
    var rewardTier: RewardTier?
    var itemsRewarded: [RewardedItem]?
    var status: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case startTime = "start_time"
        case endTime = "end_time"
        case duration
        case startLat = "start_lat"
        case startLng = "start_lng"
        case endLat = "end_lat"
        case endLng = "end_lng"
        case totalDistance = "total_distance"
        case rewardTier = "reward_tier"
        case itemsRewarded = "items_rewarded"
        case status
    }

    /// 格式化时长
    var formattedDuration: String {
        guard let duration = duration else { return "0秒" }
        let minutes = duration / 60
        let seconds = duration % 60
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)小时\(mins)分钟"
        } else if minutes > 0 {
            return "\(minutes)分\(seconds)秒"
        } else {
            return "\(seconds)秒"
        }
    }

    /// 格式化距离
    var formattedDistance: String {
        if totalDistance >= 1000 {
            return String(format: "%.2f km", totalDistance / 1000)
        } else {
            return String(format: "%.0f m", totalDistance)
        }
    }
}

/// 奖励物品（用于 JSONB 存储）
struct RewardedItem: Codable, Identifiable, Sendable {
    var id: UUID { UUID() }
    let itemId: String
    let quantity: Int
    let quality: DBItemQuality?

    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case quantity
        case quality
    }
}

/// 创建探索记录时使用的模型
struct ExplorationSessionInsert: Codable, Sendable {
    let userId: UUID
    let startTime: Date
    let startLat: Double?
    let startLng: Double?
    let status: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case startTime = "start_time"
        case startLat = "start_lat"
        case startLng = "start_lng"
        case status
    }
}

/// 更新探索记录时使用的模型
struct ExplorationSessionUpdate: Codable, Sendable {
    let endTime: Date
    let duration: Int
    let endLat: Double?
    let endLng: Double?
    let totalDistance: Double
    let rewardTier: String
    let itemsRewarded: [RewardedItem]
    let status: String

    enum CodingKeys: String, CodingKey {
        case endTime = "end_time"
        case duration
        case endLat = "end_lat"
        case endLng = "end_lng"
        case totalDistance = "total_distance"
        case rewardTier = "reward_tier"
        case itemsRewarded = "items_rewarded"
        case status
    }
}

// MARK: - InventoryItem (背包物品)
/// 对应 inventory_items 表
struct DBInventoryItem: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let itemId: String
    var quantity: Int
    let quality: DBItemQuality?
    let obtainedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case itemId = "item_id"
        case quantity
        case quality
        case obtainedAt = "obtained_at"
    }
}

/// 创建背包物品时使用的模型
struct InventoryItemInsert: Codable, Sendable {
    let userId: UUID
    let itemId: String
    let quantity: Int
    let quality: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case itemId = "item_id"
        case quantity
        case quality
    }
}
