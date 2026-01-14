//
//  ScavengePOI.swift
//  EarthLord
//
//  POI 搜刮系统数据模型
//  定义可搜刮的兴趣点结构、分类和奖励等级
//

import Foundation
import CoreLocation
import MapKit
import SwiftUI

// MARK: - POI 状态枚举

/// 可搜刮 POI 状态
enum ScavengePOIStatus: String, Codable, Sendable {
    case available = "available"    // 可搜刮
    case depleted = "depleted"      // 已搜刮（本次探索）
}

// MARK: - POI 分类枚举

/// POI 分类（映射 MKPointOfInterestCategory）
enum ScavengePOICategory: String, CaseIterable, Codable, Sendable {
    case hospital = "hospital"
    case pharmacy = "pharmacy"
    case supermarket = "supermarket"
    case convenienceStore = "convenience_store"
    case gasStation = "gas_station"
    case restaurant = "restaurant"
    case cafe = "cafe"
    case school = "school"
    case library = "library"
    case park = "park"
    case unknown = "unknown"

    /// 显示名称
    var displayName: String {
        switch self {
        case .hospital: return "医院"
        case .pharmacy: return "药店"
        case .supermarket: return "超市"
        case .convenienceStore: return "便利店"
        case .gasStation: return "加油站"
        case .restaurant: return "餐厅"
        case .cafe: return "咖啡店"
        case .school: return "学校"
        case .library: return "图书馆"
        case .park: return "公园"
        case .unknown: return "废墟"
        }
    }

    /// SF Symbol 图标名称
    var iconName: String {
        switch self {
        case .hospital: return "cross.case.fill"
        case .pharmacy: return "pills.fill"
        case .supermarket: return "cart.fill"
        case .convenienceStore: return "storefront.fill"
        case .gasStation: return "fuelpump.fill"
        case .restaurant: return "fork.knife"
        case .cafe: return "cup.and.saucer.fill"
        case .school: return "graduationcap.fill"
        case .library: return "books.vertical.fill"
        case .park: return "leaf.fill"
        case .unknown: return "mappin.circle.fill"
        }
    }

    /// 主题颜色（十六进制）
    var colorHex: String {
        switch self {
        case .hospital: return "F44336"
        case .pharmacy: return "9C27B0"
        case .supermarket: return "4CAF50"
        case .convenienceStore: return "8BC34A"
        case .gasStation: return "FF9800"
        case .restaurant: return "FF5722"
        case .cafe: return "795548"
        case .school: return "2196F3"
        case .library: return "3F51B5"
        case .park: return "009688"
        case .unknown: return "9E9E9E"
        }
    }

    /// 主题颜色
    var color: Color {
        // 使用 ApocalypseTheme 中定义的 Color(hex:) 扩展
        return Color(hex: colorHex)
    }

    /// 奖励等级
    var rewardTier: ScavengeTier {
        switch self {
        case .hospital, .pharmacy:
            return .medical
        case .supermarket, .convenienceStore:
            return .supplies
        case .gasStation:
            return .fuel
        case .restaurant, .cafe:
            return .food
        case .school, .library:
            return .tools
        case .park:
            return .nature
        case .unknown:
            return .random
        }
    }

    /// 从 MKPointOfInterestCategory 转换
    static func from(_ mkCategory: MKPointOfInterestCategory?) -> ScavengePOICategory {
        guard let mk = mkCategory else { return .unknown }
        switch mk {
        case .hospital: return .hospital
        case .pharmacy: return .pharmacy
        case .foodMarket: return .supermarket
        case .store: return .convenienceStore
        case .gasStation: return .gasStation
        case .restaurant: return .restaurant
        case .cafe: return .cafe
        case .school, .university: return .school
        case .library: return .library
        case .park, .nationalPark: return .park
        default: return .unknown
        }
    }
}

// MARK: - 搜刮奖励等级

/// 搜刮奖励等级（按 POI 类型）
enum ScavengeTier: String, Codable, Sendable {
    case medical = "medical"     // 医疗物品为主
    case supplies = "supplies"   // 食物/水为主
    case fuel = "fuel"           // 燃料/材料为主
    case food = "food"           // 食物为主
    case tools = "tools"         // 工具/材料为主
    case nature = "nature"       // 材料为主
    case random = "random"       // 随机

    /// 可能掉落的物品分类权重
    var categoryWeights: [(DBItemCategory, Double)] {
        switch self {
        case .medical:
            return [(.medical, 0.6), (.misc, 0.2), (.tool, 0.1), (.material, 0.1)]
        case .supplies:
            return [(.food, 0.4), (.water, 0.3), (.misc, 0.2), (.material, 0.1)]
        case .fuel:
            return [(.material, 0.5), (.tool, 0.3), (.misc, 0.2)]
        case .food:
            return [(.food, 0.5), (.water, 0.3), (.misc, 0.2)]
        case .tools:
            return [(.tool, 0.4), (.material, 0.3), (.misc, 0.2), (.weapon, 0.1)]
        case .nature:
            return [(.material, 0.5), (.water, 0.3), (.food, 0.2)]
        case .random:
            return [(.food, 0.2), (.water, 0.2), (.material, 0.2),
                    (.medical, 0.1), (.tool, 0.15), (.misc, 0.15)]
        }
    }
}

// MARK: - POI 模型

/// 可搜刮的兴趣点模型
struct ScavengePOI: Identifiable, Equatable, Sendable {
    let id: String                           // 唯一标识
    let name: String                         // POI 名称
    let category: ScavengePOICategory        // POI 分类
    let coordinate: CLLocationCoordinate2D   // 坐标

    var status: ScavengePOIStatus = .available  // 搜刮状态
    var lastScavengedAt: Date?               // 最后搜刮时间
    var distanceToPlayer: Double = 0         // 与玩家的距离（米）

    /// 是否在搜刮范围内（50米）
    var isInRange: Bool {
        distanceToPlayer <= 50
    }

    /// 是否可以搜刮
    var canScavenge: Bool {
        status == .available && isInRange
    }

    /// 奖励等级
    var rewardTier: ScavengeTier {
        category.rewardTier
    }

    /// 格式化距离显示
    var formattedDistance: String {
        if distanceToPlayer < 1000 {
            return "\(Int(distanceToPlayer))m"
        } else {
            return String(format: "%.1fkm", distanceToPlayer / 1000)
        }
    }

    // MARK: - Equatable

    static func == (lhs: ScavengePOI, rhs: ScavengePOI) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - CLLocationCoordinate2D Sendable

extension CLLocationCoordinate2D: @retroactive @unchecked Sendable {}
