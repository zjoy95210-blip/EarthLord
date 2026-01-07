//
//  TerritoryManager.swift
//  EarthLord
//
//  领地管理器 - 处理领地数据的上传和拉取
//

import Foundation
import CoreLocation
import Combine
import Supabase

// MARK: - TerritoryManager
@MainActor
final class TerritoryManager: ObservableObject {

    // MARK: - Singleton
    static let shared = TerritoryManager()

    // MARK: - Published Properties

    /// 所有领地列表
    @Published var territories: [Territory] = []

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - Initialization

    private init() {
        print("🏴 [领地] TerritoryManager 初始化完成")
    }

    // MARK: - 坐标转换方法

    /// 将坐标数组转换为 path JSON 格式
    /// - Parameter coordinates: CLLocationCoordinate2D 数组
    /// - Returns: [{"lat": x, "lon": y}, ...] 格式的数组
    func coordinatesToPathJSON(_ coordinates: [CLLocationCoordinate2D]) -> [[String: Double]] {
        return coordinates.map { coord in
            ["lat": coord.latitude, "lon": coord.longitude]
        }
    }

    /// 将坐标数组转换为 WKT (Well-Known Text) 格式
    /// ⚠️ WKT 格式：经度在前，纬度在后！
    /// ⚠️ 多边形必须闭合（首尾坐标相同）
    /// - Parameter coordinates: CLLocationCoordinate2D 数组
    /// - Returns: WKT 格式字符串，如 "SRID=4326;POLYGON((lon lat, lon lat, ...))"
    func coordinatesToWKT(_ coordinates: [CLLocationCoordinate2D]) -> String {
        guard coordinates.count >= 3 else {
            return ""
        }

        // 确保多边形闭合（首尾相同）
        var closedCoords = coordinates
        if let first = coordinates.first, let last = coordinates.last {
            if first.latitude != last.latitude || first.longitude != last.longitude {
                closedCoords.append(first)
            }
        }

        // 构建坐标字符串（经度在前，纬度在后）
        let coordStrings = closedCoords.map { coord in
            "\(coord.longitude) \(coord.latitude)"
        }

        let polygonString = coordStrings.joined(separator: ", ")
        return "SRID=4326;POLYGON((\(polygonString)))"
    }

    /// 计算坐标数组的边界框
    /// - Parameter coordinates: CLLocationCoordinate2D 数组
    /// - Returns: (minLat, maxLat, minLon, maxLon)
    func calculateBoundingBox(_ coordinates: [CLLocationCoordinate2D]) -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        guard !coordinates.isEmpty else {
            return (0, 0, 0, 0)
        }

        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        return (minLat, maxLat, minLon, maxLon)
    }

    // MARK: - 上传领地

    /// 上传领地到 Supabase
    /// - Parameters:
    ///   - coordinates: 领地路径坐标
    ///   - area: 领地面积（平方米）
    ///   - startTime: 开始圈地时间
    /// - Throws: 上传失败时抛出错误
    func uploadTerritory(coordinates: [CLLocationCoordinate2D], area: Double, startTime: Date) async throws {
        print("🏴 [领地] 开始上传领地，坐标点数: \(coordinates.count)，面积: \(String(format: "%.0f", area))m²")
        TerritoryLogger.shared.log("开始上传领地到服务器", type: .info)

        // 获取当前用户 ID
        guard let userId = try? await supabase.auth.session.user.id else {
            let error = "未登录，无法上传领地"
            print("❌ [领地] \(error)")
            TerritoryLogger.shared.log(error, type: .error)
            throw TerritoryError.notAuthenticated
        }

        // 转换数据格式
        let pathJSON = coordinatesToPathJSON(coordinates)
        let wktPolygon = coordinatesToWKT(coordinates)
        let bbox = calculateBoundingBox(coordinates)
        let completedTime = Date()

        // 创建插入模型
        let territoryInsert = TerritoryInsert(
            userId: userId,
            path: pathJSON,
            polygon: wktPolygon,
            bboxMinLat: bbox.minLat,
            bboxMaxLat: bbox.maxLat,
            bboxMinLon: bbox.minLon,
            bboxMaxLon: bbox.maxLon,
            area: area,
            pointCount: coordinates.count,
            startedAt: startTime.ISO8601Format(),
            completedAt: completedTime.ISO8601Format(),
            isActive: true
        )

        print("🏴 [领地] 准备上传数据:")
        print("  - user_id: \(userId)")
        print("  - point_count: \(coordinates.count)")
        print("  - area: \(area)")
        print("  - bbox: (\(bbox.minLat), \(bbox.maxLat), \(bbox.minLon), \(bbox.maxLon))")

        // 上传到 Supabase
        do {
            try await supabase
                .from("territories")
                .insert(territoryInsert)
                .execute()

            print("✅ [领地] 领地上传成功！")
            TerritoryLogger.shared.log("领地上传成功！", type: .success)

        } catch {
            print("❌ [领地] 上传失败: \(error.localizedDescription)")
            TerritoryLogger.shared.log("上传失败: \(error.localizedDescription)", type: .error)
            throw TerritoryError.uploadFailed(error.localizedDescription)
        }
    }

    // MARK: - 加载领地

    /// 加载所有有效领地
    /// - Returns: 领地数组
    func loadAllTerritories() async throws -> [Territory] {
        print("🏴 [领地] 开始加载所有领地...")
        isLoading = true
        errorMessage = nil

        do {
            let territories: [Territory] = try await supabase
                .from("territories")
                .select()
                .eq("is_active", value: true)
                .execute()
                .value

            self.territories = territories
            isLoading = false

            print("✅ [领地] 加载完成，共 \(territories.count) 个领地")
            return territories

        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            print("❌ [领地] 加载失败: \(error.localizedDescription)")
            throw TerritoryError.loadFailed(error.localizedDescription)
        }
    }

    /// 加载当前用户的领地
    /// - Returns: 领地数组
    func loadMyTerritories() async throws -> [Territory] {
        print("🏴 [领地] 开始加载我的领地...")

        guard let userId = try? await supabase.auth.session.user.id else {
            throw TerritoryError.notAuthenticated
        }

        do {
            let territories: [Territory] = try await supabase
                .from("territories")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("is_active", value: true)
                .order("created_at", ascending: false)
                .execute()
                .value

            print("✅ [领地] 加载完成，共 \(territories.count) 个我的领地")
            return territories

        } catch {
            print("❌ [领地] 加载失败: \(error.localizedDescription)")
            throw TerritoryError.loadFailed(error.localizedDescription)
        }
    }

    // MARK: - 删除领地

    /// 删除领地（软删除，设置 is_active = false）
    /// - Parameter territoryId: 领地 ID
    /// - Returns: 是否删除成功
    func deleteTerritory(territoryId: UUID) async -> Bool {
        print("🗑️ [领地] 开始删除领地: \(territoryId)")

        do {
            // 软删除：将 is_active 设为 false
            try await supabase
                .from("territories")
                .update(["is_active": false])
                .eq("id", value: territoryId.uuidString)
                .execute()

            print("✅ [领地] 领地删除成功")
            return true

        } catch {
            print("❌ [领地] 删除失败: \(error.localizedDescription)")
            return false
        }
    }

    /// 硬删除领地（从数据库中彻底删除）
    /// - Parameter territoryId: 领地 ID
    /// - Returns: 是否删除成功
    func hardDeleteTerritory(territoryId: UUID) async -> Bool {
        print("🗑️ [领地] 开始硬删除领地: \(territoryId)")

        do {
            try await supabase
                .from("territories")
                .delete()
                .eq("id", value: territoryId.uuidString)
                .execute()

            print("✅ [领地] 领地硬删除成功")
            return true

        } catch {
            print("❌ [领地] 硬删除失败: \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - 错误类型

enum TerritoryError: LocalizedError {
    case notAuthenticated
    case uploadFailed(String)
    case loadFailed(String)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "未登录，请先登录后再试"
        case .uploadFailed(let message):
            return "上传失败: \(message)"
        case .loadFailed(let message):
            return "加载失败: \(message)"
        case .invalidData:
            return "数据格式无效"
        }
    }
}
