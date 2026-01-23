//
//  BuildingModels.swift
//  EarthLord
//
//  建造系统数据模型定义
//

import Foundation
import CoreLocation

// MARK: - 建筑分类枚举
/// 建筑类型分类
enum BuildingCategory: String, Codable, CaseIterable, Sendable {
    case survival = "survival"       // 生存类
    case storage = "storage"         // 存储类
    case production = "production"   // 生产类
    case energy = "energy"           // 能源类

    /// 显示名称
    var displayName: String {
        switch self {
        case .survival: return "生存"
        case .storage: return "存储"
        case .production: return "生产"
        case .energy: return "能源"
        }
    }

    /// 图标名称
    var iconName: String {
        switch self {
        case .survival: return "flame.fill"
        case .storage: return "shippingbox.fill"
        case .production: return "gearshape.2.fill"
        case .energy: return "bolt.fill"
        }
    }

    /// 颜色（十六进制）
    var colorHex: String {
        switch self {
        case .survival: return "FF6B35"     // 橙红色
        case .storage: return "8B5A2B"      // 棕色
        case .production: return "4CAF50"   // 绿色
        case .energy: return "FFD700"       // 金色
        }
    }
}

// MARK: - 建筑状态枚举
/// 建筑当前状态
enum BuildingStatus: String, Codable, Sendable {
    case constructing = "constructing"  // 建造中
    case active = "active"              // 已激活
    case upgrading = "upgrading"        // 升级中

    /// 显示名称
    var displayName: String {
        switch self {
        case .constructing: return "建造中"
        case .active: return "已完成"
        case .upgrading: return "升级中"
        }
    }

    /// 图标名称
    var iconName: String {
        switch self {
        case .constructing: return "hammer.fill"
        case .active: return "checkmark.circle.fill"
        case .upgrading: return "arrow.up.circle.fill"
        }
    }
}

// MARK: - 建筑模板
/// 建筑模板定义（从 JSON 加载）
struct BuildingTemplate: Codable, Identifiable, Sendable {
    let id: String                          // 唯一标识符（如 "campfire"）
    let name: String                        // 显示名称
    let description: String                 // 描述
    let category: BuildingCategory          // 分类
    let tier: Int                           // 建筑等级/阶段（1-5）
    let maxPerTerritory: Int                // 每个领地最大数量
    let buildTime: Int                      // 建造时间（秒）
    let requiredMaterials: [RequiredMaterial]  // 所需材料
    let maxLevel: Int                       // 最大等级
    let iconName: String                    // 图标名称
    let effects: [BuildingEffect]?          // 建筑效果（可选）

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case category
        case tier
        case maxPerTerritory = "max_per_territory"
        case buildTime = "build_time"
        case requiredMaterials = "required_materials"
        case maxLevel = "max_level"
        case iconName = "icon_name"
        case effects
    }

    /// 格式化建造时间
    var formattedBuildTime: String {
        if buildTime >= 3600 {
            let hours = buildTime / 3600
            let minutes = (buildTime % 3600) / 60
            return "\(hours)小时\(minutes)分钟"
        } else if buildTime >= 60 {
            let minutes = buildTime / 60
            let seconds = buildTime % 60
            if seconds > 0 {
                return "\(minutes)分\(seconds)秒"
            }
            return "\(minutes)分钟"
        } else {
            return "\(buildTime)秒"
        }
    }
}

// MARK: - 所需材料
/// 建造所需的材料
struct RequiredMaterial: Codable, Sendable {
    let itemId: String      // 物品ID（对应 item_definitions.id）
    let quantity: Int       // 所需数量

    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case quantity
    }
}

// MARK: - 建筑效果（预留扩展）
/// 建筑提供的效果
struct BuildingEffect: Codable, Sendable {
    let type: String        // 效果类型（如 "storage_capacity", "production_rate"）
    let value: Double       // 效果值
    let description: String // 效果描述
}

// MARK: - 玩家建筑
/// 玩家已建造的建筑（对应数据库 player_buildings 表）
struct PlayerBuilding: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let territoryId: UUID
    let templateId: String          // 对应 BuildingTemplate.id
    var level: Int
    var status: BuildingStatus
    let startedAt: Date?            // 开始建造时间
    var completedAt: Date?          // 完成时间
    let createdAt: Date
    var locationLat: Double?        // 建筑纬度
    var locationLon: Double?        // 建筑经度

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case territoryId = "territory_id"
        case templateId = "template_id"
        case level
        case status
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case createdAt = "created_at"
        case locationLat = "location_lat"
        case locationLon = "location_lon"
    }

    /// 建筑坐标（如果有位置信息）
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = locationLat, let lon = locationLon else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// 计算剩余建造时间（秒）
    /// - Parameter buildTime: 建造所需总时间（从模板获取）
    /// - Returns: 剩余秒数，如果已完成返回 0
    func remainingBuildTime(buildTime: Int) -> Int {
        guard status == .constructing, let started = startedAt else {
            return 0
        }
        let elapsed = Int(Date().timeIntervalSince(started))
        return max(0, buildTime - elapsed)
    }

    /// 格式化剩余时间
    /// - Parameter buildTime: 建造所需总时间（从模板获取）
    /// - Returns: 格式化的时间字符串
    func formattedRemainingTime(buildTime: Int) -> String {
        let remaining = remainingBuildTime(buildTime: buildTime)
        if remaining <= 0 {
            return "已完成"
        }
        if remaining >= 3600 {
            let hours = remaining / 3600
            let minutes = (remaining % 3600) / 60
            return "\(hours)小时\(minutes)分钟"
        } else if remaining >= 60 {
            let minutes = remaining / 60
            let seconds = remaining % 60
            return "\(minutes)分\(seconds)秒"
        } else {
            return "\(remaining)秒"
        }
    }

    /// 检查是否建造完成
    /// - Parameter buildTime: 建造所需总时间
    /// - Returns: 是否已完成
    func isConstructionComplete(buildTime: Int) -> Bool {
        return remainingBuildTime(buildTime: buildTime) <= 0
    }
}

// MARK: - 数据库插入模型
/// 创建新建筑时使用的模型
struct PlayerBuildingInsert: Codable, Sendable {
    let userId: UUID
    let territoryId: UUID
    let templateId: String
    let level: Int
    let status: String
    let startedAt: Date
    let locationLat: Double?
    let locationLon: Double?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case territoryId = "territory_id"
        case templateId = "template_id"
        case level
        case status
        case startedAt = "started_at"
        case locationLat = "location_lat"
        case locationLon = "location_lon"
    }
}

// MARK: - 数据库更新模型
/// 更新建筑时使用的模型
struct PlayerBuildingUpdate: Codable, Sendable {
    var level: Int?
    var status: String?
    var completedAt: Date?

    enum CodingKeys: String, CodingKey {
        case level
        case status
        case completedAt = "completed_at"
    }
}

// MARK: - 建造错误类型
/// 建造系统错误
enum BuildingError: LocalizedError {
    case notAuthenticated           // 用户未登录
    case templateNotFound           // 模板未找到
    case insufficientMaterials      // 材料不足
    case maxBuildingsReached        // 达到最大建筑数量
    case territoryNotFound          // 领地未找到
    case buildingNotFound           // 建筑未找到
    case alreadyConstructing        // 已有建筑在建造中
    case invalidStatus              // 无效状态（如建造中无法升级）
    case jsonLoadFailed             // JSON 加载失败
    case databaseError(String)      // 数据库错误
    case invalidLocation            // 位置无效（不在领地内）

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "用户未登录"
        case .templateNotFound:
            return "建筑模板未找到"
        case .insufficientMaterials:
            return "材料不足"
        case .maxBuildingsReached:
            return "该类型建筑已达上限"
        case .territoryNotFound:
            return "领地未找到"
        case .buildingNotFound:
            return "建筑未找到"
        case .alreadyConstructing:
            return "已有建筑正在建造中"
        case .invalidStatus:
            return "建筑状态不允许此操作"
        case .jsonLoadFailed:
            return "加载建筑模板失败"
        case .databaseError(let message):
            return "数据库错误: \(message)"
        case .invalidLocation:
            return "建筑位置必须在领地范围内"
        }
    }
}

// MARK: - 建造检查结果
/// 检查是否可以建造的结果
struct BuildCheckResult: Sendable {
    let canBuild: Bool              // 是否可以建造
    let error: BuildingError?       // 如果不能建造，错误原因
    let missingMaterials: [MissingMaterial]  // 缺少的材料列表

    /// 创建成功结果
    static func success() -> BuildCheckResult {
        return BuildCheckResult(canBuild: true, error: nil, missingMaterials: [])
    }

    /// 创建失败结果
    static func failure(_ error: BuildingError, missingMaterials: [MissingMaterial] = []) -> BuildCheckResult {
        return BuildCheckResult(canBuild: false, error: error, missingMaterials: missingMaterials)
    }
}

// MARK: - 缺少的材料
/// 缺少的材料详情
struct MissingMaterial: Sendable {
    let itemId: String      // 物品ID
    let itemName: String    // 物品名称
    let required: Int       // 需要数量
    let owned: Int          // 拥有数量
    let shortage: Int       // 缺少数量
}
