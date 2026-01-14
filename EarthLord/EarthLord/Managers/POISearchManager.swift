//
//  POISearchManager.swift
//  EarthLord
//
//  POI 搜索管理器
//  封装 MKLocalSearch，搜索附近真实 POI
//

import Foundation
import MapKit
import CoreLocation
import Observation

/// POI 搜索管理器
@MainActor
@Observable
final class POISearchManager {

    // MARK: - Singleton

    static let shared = POISearchManager()

    // MARK: - Published Properties

    /// 搜索到的 POI 列表
    var pois: [ScavengePOI] = []

    /// 是否正在搜索
    var isSearching: Bool = false

    /// 搜索错误信息
    var searchError: String?

    /// 上次搜索位置
    var lastSearchLocation: CLLocationCoordinate2D?

    /// 上次搜索时间
    var lastSearchTime: Date?

    // MARK: - Constants

    /// 搜索半径（米）
    private let searchRadius: CLLocationDistance = 1000

    /// 最小搜索间隔（秒）- 防止频繁搜索
    private let minSearchInterval: TimeInterval = 30

    /// 要搜索的关键词和对应的 POI 类别
    /// 使用自然语言搜索，兼容性更好
    private let searchQueries: [(query: String, category: ScavengePOICategory)] = [
        ("医院", .hospital),
        ("药店", .pharmacy),
        ("药房", .pharmacy),
        ("超市", .supermarket),
        ("便利店", .supermarket),
        ("加油站", .gasStation),
        ("餐厅", .restaurant),
        ("餐馆", .restaurant),
        ("咖啡", .cafe),
        ("学校", .school),
        ("大学", .school),
        ("图书馆", .library),
        ("公园", .park),
        ("商店", .supermarket)
    ]

    // MARK: - Init

    private init() {}

    // MARK: - Public Methods

    /// 搜索附近 POI
    /// - Parameters:
    ///   - center: 搜索中心点坐标
    ///   - forceRefresh: 是否强制刷新（忽略时间间隔）
    func searchNearbyPOIs(center: CLLocationCoordinate2D, forceRefresh: Bool = false) async {
        // 检查搜索间隔
        if !forceRefresh, let lastTime = lastSearchTime {
            let elapsed = Date().timeIntervalSince(lastTime)
            if elapsed < minSearchInterval {
                print("🔍 [POI搜索] 搜索间隔不足，跳过 (剩余 \(Int(minSearchInterval - elapsed))秒)")
                return
            }
        }

        isSearching = true
        searchError = nil
        lastSearchLocation = center
        lastSearchTime = Date()

        print("🔍 [POI搜索] 开始搜索，中心: (\(String(format: "%.6f", center.latitude)), \(String(format: "%.6f", center.longitude)))，半径: \(searchRadius)m")

        var allPOIs: [ScavengePOI] = []

        // 并发搜索多个关键词
        await withTaskGroup(of: [ScavengePOI].self) { group in
            for (query, category) in searchQueries {
                group.addTask {
                    await self.searchPOIs(center: center, query: query, category: category)
                }
            }

            for await categoryPOIs in group {
                allPOIs.append(contentsOf: categoryPOIs)
            }
        }

        // 去重（根据 ID）
        var uniquePOIs: [String: ScavengePOI] = [:]
        for poi in allPOIs {
            uniquePOIs[poi.id] = poi
        }

        // 按距离排序
        let sortedPOIs = Array(uniquePOIs.values).sorted { $0.distanceToPlayer < $1.distanceToPlayer }

        // 限制最多显示 20 个（因为地理围栏限制）
        pois = Array(sortedPOIs.prefix(20))

        isSearching = false
        print("🔍 [POI搜索] 搜索完成，共找到 \(pois.count) 个 POI")

        // 打印 POI 列表
        for (index, poi) in pois.enumerated() {
            print("   \(index + 1). \(poi.category.displayName) - \(poi.name) (\(Int(poi.distanceToPlayer))m)")
        }
    }

    /// 更新所有 POI 与玩家的距离
    func updateDistances(playerLocation: CLLocationCoordinate2D) {
        let playerCL = CLLocation(latitude: playerLocation.latitude, longitude: playerLocation.longitude)

        for index in pois.indices {
            let poiCL = CLLocation(latitude: pois[index].coordinate.latitude,
                                   longitude: pois[index].coordinate.longitude)
            pois[index].distanceToPlayer = playerCL.distance(from: poiCL)
        }

        // 重新按距离排序
        pois.sort { $0.distanceToPlayer < $1.distanceToPlayer }
    }

    /// 标记 POI 为已搜刮
    func markAsScavenged(poiId: String) {
        if let index = pois.firstIndex(where: { $0.id == poiId }) {
            pois[index].status = .depleted
            pois[index].lastScavengedAt = Date()
            print("🎒 [POI搜索] 标记 POI 已搜刮: \(pois[index].name)")
        }
    }

    /// 获取范围内的可搜刮 POI
    func getPOIsInRange() -> [ScavengePOI] {
        return pois.filter { $0.isInRange && $0.canScavenge }
    }

    /// 获取指定 ID 的 POI
    func getPOI(byId id: String) -> ScavengePOI? {
        return pois.first { $0.id == id }
    }

    /// 清除搜索结果
    func clearPOIs() {
        pois = []
        lastSearchLocation = nil
        lastSearchTime = nil
        searchError = nil
        print("🔍 [POI搜索] 已清除所有 POI")
    }

    // MARK: - Private Methods

    /// 使用自然语言搜索 POI
    private func searchPOIs(center: CLLocationCoordinate2D, query: String, category: ScavengePOICategory) async -> [ScavengePOI] {
        // 创建搜索请求
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query

        // 设置搜索区域
        let region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: searchRadius * 2,
            longitudinalMeters: searchRadius * 2
        )
        request.region = region

        let search = MKLocalSearch(request: request)

        do {
            let response = try await search.start()
            let playerCL = CLLocation(latitude: center.latitude, longitude: center.longitude)

            let result = response.mapItems.compactMap { mapItem -> ScavengePOI? in
                // 使用 location 替代已废弃的 placemark.location
                let location = mapItem.location

                // 计算距离
                let distance = playerCL.distance(from: location)

                // 只保留搜索半径内的结果
                guard distance <= searchRadius else { return nil }

                // 生成唯一 ID
                let id = generatePOIId(mapItem: mapItem)

                return ScavengePOI(
                    id: id,
                    name: mapItem.name ?? "未知地点",
                    category: category,
                    coordinate: location.coordinate,
                    status: .available,
                    lastScavengedAt: nil,
                    distanceToPlayer: distance
                )
            }

            if !result.isEmpty {
                print("🔍 [POI搜索] '\(query)': 找到 \(result.count) 个")
            }
            return result
        } catch {
            print("❌ [POI搜索] 搜索 '\(query)' 失败: \(error.localizedDescription)")
            return []
        }
    }

    /// 生成 POI 唯一标识
    private func generatePOIId(mapItem: MKMapItem) -> String {
        // 使用名称+坐标生成唯一ID
        let name = mapItem.name ?? "unknown"
        // 使用 location 替代已废弃的 placemark.coordinate
        let coordinate = mapItem.location.coordinate
        let lat = String(format: "%.6f", coordinate.latitude)
        let lng = String(format: "%.6f", coordinate.longitude)
        return "\(name)_\(lat)_\(lng)"
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "_")
    }
}
