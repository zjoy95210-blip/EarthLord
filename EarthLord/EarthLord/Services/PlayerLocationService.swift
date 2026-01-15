//
//  PlayerLocationService.swift
//  EarthLord
//
//  玩家位置服务
//  负责位置上报和附近玩家查询
//
//  功能：
//  1. 定期上报位置（每30秒）
//  2. 移动超过50米时上报
//  3. App进入后台时标记离线
//  4. 查询附近玩家数量
//

import Foundation
import CoreLocation
import Observation
import Supabase
#if os(iOS)
import UIKit
#endif

// MARK: - 玩家密度等级

/// 玩家密度等级
enum PlayerDensityLevel: String, CaseIterable {
    case solo = "solo"           // 独行者：0人
    case low = "low"             // 低密度：1-5人
    case medium = "medium"       // 中密度：6-20人
    case high = "high"           // 高密度：20人以上

    /// 显示名称
    var displayName: String {
        switch self {
        case .solo: return "独行者"
        case .low: return "低密度"
        case .medium: return "中密度"
        case .high: return "高密度"
        }
    }

    /// 建议显示的 POI 数量
    var suggestedPOICount: Int {
        switch self {
        case .solo: return 1
        case .low: return 3
        case .medium: return 6
        case .high: return 20  // 显示所有
        }
    }

    /// 根据附近玩家数量确定密度等级
    static func from(nearbyPlayerCount: Int) -> PlayerDensityLevel {
        switch nearbyPlayerCount {
        case 0:
            return .solo
        case 1...5:
            return .low
        case 6...20:
            return .medium
        default:
            return .high
        }
    }
}

// MARK: - 玩家位置服务

/// 玩家位置服务
@MainActor
@Observable
final class PlayerLocationService: NSObject {

    // MARK: - Singleton

    static let shared = PlayerLocationService()

    // MARK: - Published Properties

    /// 是否正在上报位置
    var isReporting: Bool = false

    /// 上次上报时间
    var lastReportTime: Date?

    /// 上次上报位置
    var lastReportedLocation: CLLocationCoordinate2D?

    /// 附近玩家数量
    var nearbyPlayerCount: Int = 0

    /// 当前密度等级
    var currentDensityLevel: PlayerDensityLevel {
        PlayerDensityLevel.from(nearbyPlayerCount: nearbyPlayerCount)
    }

    /// 上报错误信息
    var lastError: String?

    // MARK: - Constants

    /// 上报间隔（秒）
    private let reportInterval: TimeInterval = 30

    /// 位置变化阈值（米）
    private let movementThreshold: CLLocationDistance = 50

    /// 查询半径（米）
    private let queryRadius: Int = 1000

    // MARK: - Private Properties

    /// 位置管理器
    private var locationManager: CLLocationManager?

    /// 定时上报定时器
    private var reportTimer: Timer?

    /// 后台任务标识
    #if os(iOS)
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    #endif

    // MARK: - Init

    private override init() {
        super.init()
        setupLocationManager()
        setupAppLifecycleObservers()
    }

    // MARK: - Setup

    private func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager?.distanceFilter = movementThreshold
    }

    private func setupAppLifecycleObservers() {
        #if os(iOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        #endif
    }

    // MARK: - Public Methods

    /// 开始位置上报服务
    func startReporting() {
        guard !isReporting else {
            print("📍 [位置服务] 已在上报中，跳过启动")
            return
        }

        isReporting = true
        lastError = nil

        // 开始位置更新
        locationManager?.startUpdatingLocation()

        // 启动定时上报
        startReportTimer()

        // 立即上报一次
        if let location = locationManager?.location {
            Task {
                await reportLocation(location.coordinate)
            }
        }

        print("📍 [位置服务] 开始位置上报服务")
    }

    /// 停止位置上报服务
    func stopReporting() {
        guard isReporting else { return }

        isReporting = false

        // 停止位置更新
        locationManager?.stopUpdatingLocation()

        // 停止定时器
        stopReportTimer()

        // 标记离线
        Task {
            await markOffline()
        }

        print("📍 [位置服务] 停止位置上报服务")
    }

    /// 上报当前位置
    func reportCurrentLocation() async {
        guard let location = locationManager?.location else {
            print("⚠️ [位置服务] 无法获取当前位置")
            return
        }

        await reportLocation(location.coordinate)
    }

    /// 查询附近玩家数量
    func queryNearbyPlayers() async -> Int {
        guard let location = locationManager?.location else {
            print("⚠️ [位置服务] 无法查询附近玩家：位置未知")
            return 0
        }

        return await queryNearbyPlayers(at: location.coordinate)
    }

    /// 查询指定位置附近的玩家数量
    func queryNearbyPlayers(at coordinate: CLLocationCoordinate2D) async -> Int {
        do {
            let userId = supabase.auth.currentUser?.id

            // 获取 5 分钟内活跃的玩家位置
            let fiveMinutesAgo = Date().addingTimeInterval(-300)

            // 获取所有活跃玩家位置
            let locations: [PlayerLocation] = try await supabase
                .from("player_locations")
                .select("user_id, latitude, longitude, last_updated")
                .gte("last_updated", value: ISO8601DateFormatter().string(from: fiveMinutesAgo))
                .execute()
                .value

            // 在本地计算距离过滤
            let centerCL = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let nearbyCount = locations.filter { location in
                // 排除自己
                if let myId = userId, location.userId == myId {
                    return false
                }

                // 计算距离
                let locationCL = CLLocation(latitude: location.latitude, longitude: location.longitude)
                let distance = centerCL.distance(from: locationCL)
                return distance <= Double(queryRadius)
            }.count

            nearbyPlayerCount = nearbyCount
            print("📍 [位置服务] 附近玩家数量: \(nearbyCount) (\(currentDensityLevel.displayName))")

            return nearbyCount

        } catch {
            print("❌ [位置服务] 查询附近玩家失败: \(error.localizedDescription)")
            lastError = error.localizedDescription
            return 0
        }
    }

    /// 获取建议的 POI 数量
    func getSuggestedPOICount() -> Int {
        return currentDensityLevel.suggestedPOICount
    }

    // MARK: - Private Methods

    /// 上报位置到服务器
    private func reportLocation(_ coordinate: CLLocationCoordinate2D) async {
        guard let userId = supabase.auth.currentUser?.id else {
            print("⚠️ [位置服务] 未登录，无法上报位置")
            return
        }

        do {
            let insert = PlayerLocationInsert(
                userId: userId,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )

            // 使用 UPSERT 更新或插入
            try await supabase
                .from("player_locations")
                .upsert(insert, onConflict: "user_id")
                .execute()

            lastReportTime = Date()
            lastReportedLocation = coordinate

            print("📍 [位置服务] 位置上报成功: (\(String(format: "%.6f", coordinate.latitude)), \(String(format: "%.6f", coordinate.longitude)))")

        } catch {
            print("❌ [位置服务] 位置上报失败: \(error.localizedDescription)")
            lastError = error.localizedDescription
        }
    }

    /// 标记离线
    private func markOffline() async {
        guard let userId = supabase.auth.currentUser?.id else {
            return
        }

        do {
            try await supabase
                .from("player_locations")
                .update(["is_online": false])
                .eq("user_id", value: userId)
                .execute()

            print("📍 [位置服务] 已标记为离线")

        } catch {
            print("❌ [位置服务] 标记离线失败: \(error.localizedDescription)")
        }
    }

    /// 启动定时上报
    private func startReportTimer() {
        stopReportTimer()

        reportTimer = Timer.scheduledTimer(withTimeInterval: reportInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                await self.reportCurrentLocation()
            }
        }
    }

    /// 停止定时上报
    private func stopReportTimer() {
        reportTimer?.invalidate()
        reportTimer = nil
    }

    /// 检查是否需要上报（基于移动距离）
    private func shouldReport(newLocation: CLLocation) -> Bool {
        guard let lastLocation = lastReportedLocation else {
            return true  // 首次上报
        }

        let lastCL = CLLocation(latitude: lastLocation.latitude, longitude: lastLocation.longitude)
        let distance = newLocation.distance(from: lastCL)

        return distance >= movementThreshold
    }

    // MARK: - App Lifecycle

    @objc private func appWillEnterForeground() {
        print("📍 [位置服务] App 进入前台")

        if isReporting {
            // 恢复位置更新
            locationManager?.startUpdatingLocation()
            startReportTimer()

            // 立即上报一次
            Task {
                await reportCurrentLocation()
            }
        }
    }

    @objc private func appDidEnterBackground() {
        print("📍 [位置服务] App 进入后台")

        #if os(iOS)
        // 请求后台任务时间
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }

        // 在后台完成离线标记
        Task {
            await markOffline()
            endBackgroundTask()
        }
        #endif

        // 停止定时器
        stopReportTimer()
    }

    #if os(iOS)
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    #endif
}

// MARK: - CLLocationManagerDelegate

extension PlayerLocationService: CLLocationManagerDelegate {

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard isReporting, let location = locations.last else { return }

            // 检查是否需要基于移动距离上报
            if shouldReport(newLocation: location) {
                await reportLocation(location.coordinate)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            print("❌ [位置服务] 位置更新失败: \(error.localizedDescription)")
            lastError = error.localizedDescription
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            print("📍 [位置服务] 授权状态变更: \(manager.authorizationStatus.rawValue)")
        }
    }
}

// MARK: - 数据模型

/// 玩家位置（用于查询）
struct PlayerLocation: Decodable {
    let userId: UUID
    let latitude: Double
    let longitude: Double
    let lastUpdated: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case latitude
        case longitude
        case lastUpdated = "last_updated"
    }
}

/// 玩家位置插入模型
struct PlayerLocationInsert: Encodable {
    let userId: UUID
    let latitude: Double
    let longitude: Double
    let isOnline: Bool = true

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case latitude
        case longitude
        case isOnline = "is_online"
    }
}
