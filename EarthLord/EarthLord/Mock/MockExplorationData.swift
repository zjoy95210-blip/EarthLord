//
//  MockExplorationData.swift
//  EarthLord
//
//  探索模块测试假数据
//  用于开发和测试探索功能的 UI 展示
//

import Foundation
import CoreLocation

// MARK: - 探索 POI 状态

/// POI 发现状态
enum POIDiscoveryStatus: String, Codable {
    case undiscovered = "undiscovered"  // 未发现（地图上不显示或显示为问号）
    case discovered = "discovered"       // 已发现（可以查看详情）
    case looted = "looted"              // 已搜刮（物资已被搜空）
}

/// POI 物资状态
enum POIResourceStatus: String, Codable {
    case hasResources = "has_resources"  // 有物资可搜刮
    case empty = "empty"                 // 已被搜空
    case unknown = "unknown"             // 未知（未发现时）
}

// MARK: - 探索 POI 坐标（Mock 专用）

/// Mock 用的简单坐标结构
struct MockCoordinate: Codable {
    let latitude: Double
    let longitude: Double
}

// MARK: - 探索 POI 模型

/// 探索用的 POI 数据模型
struct ExplorationPOI: Identifiable, Codable {
    let id: String
    let name: String                      // POI 名称
    let type: String                      // POI 类型字符串
    let coordinate: MockCoordinate        // 位置坐标
    let discoveryStatus: POIDiscoveryStatus  // 发现状态
    let resourceStatus: POIResourceStatus    // 物资状态
    let poiDescription: String?           // 描述信息
    let lastVisitedAt: Date?             // 最后访问时间

    /// 是否可以搜刮
    var canLoot: Bool {
        return discoveryStatus == .discovered && resourceStatus == .hasResources
    }

    /// 显示名称（未发现时显示问号）
    var displayName: String {
        return discoveryStatus == .undiscovered ? "???" : name
    }

    /// POI 类型图标
    var iconName: String {
        switch type {
        case "supermarket": return "cart.fill"
        case "hospital": return "cross.case.fill"
        case "gas_station": return "fuelpump.fill"
        case "factory": return "building.2.fill"
        default: return "mappin.circle.fill"
        }
    }

    /// POI 类型显示名称
    var typeDisplayName: String {
        switch type {
        case "supermarket": return "超市"
        case "hospital": return "医院"
        case "gas_station": return "加油站"
        case "factory": return "工厂"
        default: return "未知"
        }
    }
}

// MARK: - 物品相关模型

/// 物品分类
enum ItemCategory: String, Codable, CaseIterable {
    case water = "water"           // 水类
    case food = "food"             // 食物
    case medical = "medical"       // 医疗
    case material = "material"     // 材料
    case tool = "tool"             // 工具
    case weapon = "weapon"         // 武器
    case clothing = "clothing"     // 服装
    case misc = "misc"             // 杂项

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

/// 物品稀有度
enum ItemRarity: String, Codable, CaseIterable {
    case common = "common"         // 普通（灰色）
    case uncommon = "uncommon"     // 优秀（绿色）
    case rare = "rare"             // 稀有（蓝色）
    case epic = "epic"             // 史诗（紫色）
    case legendary = "legendary"   // 传说（橙色）

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
        case .common: return "9E9E9E"      // 灰色
        case .uncommon: return "4CAF50"    // 绿色
        case .rare: return "2196F3"        // 蓝色
        case .epic: return "9C27B0"        // 紫色
        case .legendary: return "FF9800"   // 橙色
        }
    }
}

/// 物品品质（可选，部分物品没有品质）
enum ItemQuality: String, Codable {
    case broken = "broken"         // 破损（50%效果）
    case worn = "worn"             // 磨损（75%效果）
    case normal = "normal"         // 正常（100%效果）
    case fine = "fine"             // 精良（110%效果）
    case pristine = "pristine"     // 完美（125%效果）

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
}

/// 物品定义（静态配置表）
struct ItemDefinition: Identifiable, Codable {
    let id: String                 // 物品唯一标识符
    let name: String               // 中文名称
    let category: ItemCategory     // 分类
    let weight: Double             // 单个重量（kg）
    let volume: Double             // 单个体积（升）
    let rarity: ItemRarity         // 稀有度
    let maxStack: Int              // 最大堆叠数量
    let description: String        // 物品描述
    let hasQuality: Bool           // 是否有品质属性
}

/// 背包物品（实例）
struct BackpackItem: Identifiable, Codable {
    let id: UUID                   // 实例唯一 ID
    let itemId: String             // 物品定义 ID
    var quantity: Int              // 数量
    let quality: ItemQuality?      // 品质（可选）
    let obtainedAt: Date           // 获得时间

    /// 计算总重量
    func totalWeight(definition: ItemDefinition) -> Double {
        return definition.weight * Double(quantity)
    }

    /// 计算总体积
    func totalVolume(definition: ItemDefinition) -> Double {
        return definition.volume * Double(quantity)
    }
}

// MARK: - 探索结果模型

/// 探索结果统计
struct ExplorationResult: Codable {
    // 本次探索数据
    let sessionDistance: Double        // 本次行走距离（米）
    let sessionArea: Double            // 本次探索面积（平方米）
    let sessionDuration: TimeInterval  // 本次探索时长（秒）
    let sessionStartTime: Date         // 本次开始时间
    let sessionEndTime: Date           // 本次结束时间

    // 累计数据
    let totalDistance: Double          // 累计行走距离（米）
    let totalArea: Double              // 累计探索面积（平方米）
    let totalDuration: TimeInterval    // 累计探索时长（秒）

    // 排名数据
    let distanceRank: Int              // 行走距离排名
    let areaRank: Int                  // 探索面积排名

    // 获得物品
    let obtainedItems: [ObtainedItem]  // 本次获得的物品列表

    /// 格式化本次距离
    var formattedSessionDistance: String {
        if sessionDistance >= 1000 {
            return String(format: "%.2f km", sessionDistance / 1000)
        } else {
            return String(format: "%.0f m", sessionDistance)
        }
    }

    /// 格式化本次面积
    var formattedSessionArea: String {
        if sessionArea >= 10000 {
            return String(format: "%.2f 万m²", sessionArea / 10000)
        } else {
            return String(format: "%.0f m²", sessionArea)
        }
    }

    /// 格式化本次时长
    var formattedSessionDuration: String {
        let minutes = Int(sessionDuration) / 60
        let seconds = Int(sessionDuration) % 60
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)小时\(mins)分钟"
        } else {
            return "\(minutes)分\(seconds)秒"
        }
    }
}

/// 获得的物品
struct ObtainedItem: Identifiable, Codable {
    let id: UUID
    let itemId: String             // 物品定义 ID
    let quantity: Int              // 数量
    let quality: ItemQuality?      // 品质（可选）
}

// MARK: - Mock 数据类

/// 探索模块假数据
/// 用于开发测试，正式版本应从服务器获取
struct MockExplorationData {

    // MARK: - 物品定义表

    /// 所有物品的定义配置
    /// 实际项目中应该从配置文件或服务器加载
    static let itemDefinitions: [ItemDefinition] = [
        // 水类
        ItemDefinition(
            id: "water_bottle",
            name: "矿泉水",
            category: .water,
            weight: 0.5,
            volume: 0.5,
            rarity: .common,
            maxStack: 10,
            description: "一瓶干净的饮用水，末日中的珍贵资源。",
            hasQuality: false
        ),
        ItemDefinition(
            id: "purified_water",
            name: "净化水",
            category: .water,
            weight: 0.5,
            volume: 0.5,
            rarity: .uncommon,
            maxStack: 10,
            description: "经过过滤净化的水，更加安全。",
            hasQuality: false
        ),

        // 食物
        ItemDefinition(
            id: "canned_food",
            name: "罐头食品",
            category: .food,
            weight: 0.4,
            volume: 0.3,
            rarity: .common,
            maxStack: 20,
            description: "保质期很长的罐头食品，虽然味道一般但能填饱肚子。",
            hasQuality: false
        ),
        ItemDefinition(
            id: "energy_bar",
            name: "能量棒",
            category: .food,
            weight: 0.1,
            volume: 0.05,
            rarity: .uncommon,
            maxStack: 30,
            description: "高热量的能量补给品，适合快速恢复体力。",
            hasQuality: false
        ),

        // 医疗
        ItemDefinition(
            id: "bandage",
            name: "绷带",
            category: .medical,
            weight: 0.05,
            volume: 0.02,
            rarity: .common,
            maxStack: 50,
            description: "基础的医疗用品，可以处理轻微伤口。",
            hasQuality: true
        ),
        ItemDefinition(
            id: "medicine",
            name: "药品",
            category: .medical,
            weight: 0.1,
            volume: 0.05,
            rarity: .rare,
            maxStack: 20,
            description: "各种常用药品，在末日中非常珍贵。",
            hasQuality: true
        ),
        ItemDefinition(
            id: "first_aid_kit",
            name: "急救包",
            category: .medical,
            weight: 0.8,
            volume: 0.5,
            rarity: .rare,
            maxStack: 5,
            description: "完整的急救包，包含多种医疗用品。",
            hasQuality: true
        ),

        // 材料
        ItemDefinition(
            id: "wood",
            name: "木材",
            category: .material,
            weight: 1.0,
            volume: 0.8,
            rarity: .common,
            maxStack: 99,
            description: "基础的建筑材料，用途广泛。",
            hasQuality: false
        ),
        ItemDefinition(
            id: "scrap_metal",
            name: "废金属",
            category: .material,
            weight: 0.5,
            volume: 0.2,
            rarity: .common,
            maxStack: 99,
            description: "从废墟中收集的金属碎片，可以用于制作。",
            hasQuality: false
        ),
        ItemDefinition(
            id: "electronic_parts",
            name: "电子元件",
            category: .material,
            weight: 0.2,
            volume: 0.1,
            rarity: .uncommon,
            maxStack: 50,
            description: "从废弃电子设备中拆解的零件。",
            hasQuality: false
        ),

        // 工具
        ItemDefinition(
            id: "flashlight",
            name: "手电筒",
            category: .tool,
            weight: 0.3,
            volume: 0.15,
            rarity: .common,
            maxStack: 1,
            description: "便携式手电筒，夜间探索必备。",
            hasQuality: true
        ),
        ItemDefinition(
            id: "rope",
            name: "绳子",
            category: .tool,
            weight: 0.5,
            volume: 0.3,
            rarity: .common,
            maxStack: 5,
            description: "结实的绳子，有多种用途。",
            hasQuality: true
        ),
        ItemDefinition(
            id: "lockpick",
            name: "撬锁工具",
            category: .tool,
            weight: 0.1,
            volume: 0.02,
            rarity: .rare,
            maxStack: 10,
            description: "专业的撬锁工具，可以打开上锁的门和箱子。",
            hasQuality: true
        ),
    ]

    /// 根据 ID 获取物品定义
    static func getItemDefinition(by id: String) -> ItemDefinition? {
        return itemDefinitions.first { $0.id == id }
    }

    // MARK: - POI 假数据

    /// 5 个不同状态的探索 POI
    /// 用于测试 POI 列表和地图显示
    static let explorationPOIs: [ExplorationPOI] = [
        // 废弃超市：已发现，有物资
        ExplorationPOI(
            id: "poi_supermarket_001",
            name: "废弃超市",
            type: "supermarket",
            coordinate: MockCoordinate(latitude: 31.2304, longitude: 121.4737),
            discoveryStatus: .discovered,
            resourceStatus: .hasResources,
            poiDescription: "一家废弃的大型超市，货架上可能还有一些物资。",
            lastVisitedAt: Date().addingTimeInterval(-86400)  // 1天前
        ),

        // 医院废墟：已发现，已被搜空
        ExplorationPOI(
            id: "poi_hospital_001",
            name: "医院废墟",
            type: "hospital",
            coordinate: MockCoordinate(latitude: 31.2350, longitude: 121.4800),
            discoveryStatus: .discovered,
            resourceStatus: .empty,
            poiDescription: "曾经的医院，现在只剩下废墟。医疗物资已经被搜刮一空。",
            lastVisitedAt: Date().addingTimeInterval(-172800)  // 2天前
        ),

        // 加油站：未发现
        ExplorationPOI(
            id: "poi_gasstation_001",
            name: "加油站",
            type: "gas_station",
            coordinate: MockCoordinate(latitude: 31.2280, longitude: 121.4680),
            discoveryStatus: .undiscovered,
            resourceStatus: .unknown,
            poiDescription: nil,
            lastVisitedAt: nil
        ),

        // 药店废墟：已发现，有物资
        ExplorationPOI(
            id: "poi_pharmacy_001",
            name: "药店废墟",
            type: "hospital",  // 使用 hospital 类型代表医疗相关
            coordinate: MockCoordinate(latitude: 31.2320, longitude: 121.4750),
            discoveryStatus: .discovered,
            resourceStatus: .hasResources,
            poiDescription: "一家小型药店，虽然遭到破坏但可能还有一些药品。",
            lastVisitedAt: Date().addingTimeInterval(-43200)  // 12小时前
        ),

        // 工厂废墟：未发现
        ExplorationPOI(
            id: "poi_factory_001",
            name: "工厂废墟",
            type: "factory",
            coordinate: MockCoordinate(latitude: 31.2400, longitude: 121.4850),
            discoveryStatus: .undiscovered,
            resourceStatus: .unknown,
            poiDescription: nil,
            lastVisitedAt: nil
        ),
    ]

    // MARK: - 背包物品假数据

    /// 玩家背包中的物品列表
    /// 包含 8 种不同类型的物品，部分有品质属性
    static let backpackItems: [BackpackItem] = [
        // 水类：矿泉水 x5
        BackpackItem(
            id: UUID(),
            itemId: "water_bottle",
            quantity: 5,
            quality: nil,  // 水没有品质
            obtainedAt: Date().addingTimeInterval(-3600)
        ),

        // 食物：罐头食品 x8
        BackpackItem(
            id: UUID(),
            itemId: "canned_food",
            quantity: 8,
            quality: nil,  // 食物没有品质
            obtainedAt: Date().addingTimeInterval(-7200)
        ),

        // 医疗：绷带 x12（正常品质）
        BackpackItem(
            id: UUID(),
            itemId: "bandage",
            quantity: 12,
            quality: .normal,
            obtainedAt: Date().addingTimeInterval(-1800)
        ),

        // 医疗：药品 x3（精良品质）
        BackpackItem(
            id: UUID(),
            itemId: "medicine",
            quantity: 3,
            quality: .fine,
            obtainedAt: Date().addingTimeInterval(-86400)
        ),

        // 材料：木材 x25
        BackpackItem(
            id: UUID(),
            itemId: "wood",
            quantity: 25,
            quality: nil,  // 材料没有品质
            obtainedAt: Date().addingTimeInterval(-14400)
        ),

        // 材料：废金属 x18
        BackpackItem(
            id: UUID(),
            itemId: "scrap_metal",
            quantity: 18,
            quality: nil,
            obtainedAt: Date().addingTimeInterval(-10800)
        ),

        // 工具：手电筒 x1（磨损品质）
        BackpackItem(
            id: UUID(),
            itemId: "flashlight",
            quantity: 1,
            quality: .worn,
            obtainedAt: Date().addingTimeInterval(-172800)
        ),

        // 工具：绳子 x2（正常品质）
        BackpackItem(
            id: UUID(),
            itemId: "rope",
            quantity: 2,
            quality: .normal,
            obtainedAt: Date().addingTimeInterval(-43200)
        ),
    ]

    /// 计算背包总重量
    static var totalBackpackWeight: Double {
        var total = 0.0
        for item in backpackItems {
            if let definition = getItemDefinition(by: item.itemId) {
                total += item.totalWeight(definition: definition)
            }
        }
        return total
    }

    /// 计算背包总体积
    static var totalBackpackVolume: Double {
        var total = 0.0
        for item in backpackItems {
            if let definition = getItemDefinition(by: item.itemId) {
                total += item.totalVolume(definition: definition)
            }
        }
        return total
    }

    // MARK: - 探索结果假数据

    /// 探索结果示例
    /// 模拟一次 30 分钟的探索结果
    static let sampleExplorationResult = ExplorationResult(
        // 本次探索数据
        sessionDistance: 2500,           // 本次行走 2500 米
        sessionArea: 50000,              // 本次探索 5 万平方米
        sessionDuration: 1800,           // 本次探索 30 分钟
        sessionStartTime: Date().addingTimeInterval(-1800),
        sessionEndTime: Date(),

        // 累计数据
        totalDistance: 15000,            // 累计行走 15000 米
        totalArea: 250000,               // 累计探索 25 万平方米
        totalDuration: 18000,            // 累计探索 5 小时

        // 排名数据
        distanceRank: 42,                // 行走距离排名第 42
        areaRank: 38,                    // 探索面积排名第 38

        // 获得物品
        obtainedItems: [
            ObtainedItem(id: UUID(), itemId: "wood", quantity: 5, quality: nil),
            ObtainedItem(id: UUID(), itemId: "water_bottle", quantity: 3, quality: nil),
            ObtainedItem(id: UUID(), itemId: "canned_food", quantity: 2, quality: nil),
            ObtainedItem(id: UUID(), itemId: "bandage", quantity: 4, quality: .normal),
        ]
    )

    // MARK: - 辅助方法

    /// 获取物品显示名称（包含品质）
    static func getItemDisplayName(item: BackpackItem) -> String {
        guard let definition = getItemDefinition(by: item.itemId) else {
            return "未知物品"
        }

        if let quality = item.quality {
            return "[\(quality.displayName)] \(definition.name)"
        } else {
            return definition.name
        }
    }

    /// 获取物品完整描述
    static func getItemFullDescription(item: BackpackItem) -> String {
        guard let definition = getItemDefinition(by: item.itemId) else {
            return "未知物品"
        }

        var desc = "\(definition.name)\n"
        desc += "分类：\(definition.category.displayName)\n"
        desc += "稀有度：\(definition.rarity.displayName)\n"
        desc += "数量：\(item.quantity)\n"
        desc += "重量：\(String(format: "%.2f", item.totalWeight(definition: definition))) kg\n"

        if let quality = item.quality {
            desc += "品质：\(quality.displayName)（\(Int(quality.effectMultiplier * 100))%效果）\n"
        }

        desc += "\n\(definition.description)"

        return desc
    }
}
