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
