//
//  ExplorationManager.swift
//  EarthLord
//
//  探索管理器
//  负责管理探索状态、GPS追踪、距离计算和计时
//

import Foundation
import CoreLocation
import Observation
#if os(iOS)
import UIKit
#endif

/// 探索状态枚举
enum ExplorationState: Equatable {
    case idle           // 空闲状态
    case exploring      // 探索中
    case finishing      // 结算中
    case completed      // 已完成
    case failed(String) // 失败
}

/// 超速状态枚举
enum OverSpeedState: Equatable {
    case normal         // 正常速度
    case warning        // 超速警告中
    case stopped        // 因超速停止
}

/// 探索管理器
@MainActor
@Observable
final class ExplorationManager: NSObject {

    // MARK: - Singleton
    static let shared = ExplorationManager()

    // MARK: - Published Properties

    /// 当前探索状态
    var state: ExplorationState = .idle

    /// 累计行走距离（米）
    var totalDistance: Double = 0

    /// 探索时长（秒）
    var duration: Int = 0

    /// 当前会话 ID
    var currentSessionId: UUID?

    /// 起始坐标
    var startCoordinate: CLLocationCoordinate2D?

    /// 当前坐标
    var currentCoordinate: CLLocationCoordinate2D?

    /// 是否正在探索
    var isExploring: Bool {
        state == .exploring
    }

    // MARK: - 速度相关属性

    /// 当前速度（km/h）
    var currentSpeed: Double = 0

    /// 超速状态
    var overSpeedState: OverSpeedState = .normal

    /// 是否超速
    var isOverSpeed: Bool {
        overSpeedState == .warning
    }

    /// 超速剩余时间（秒）- 用于 UI 显示倒计时
    var overSpeedRemainingSeconds: Int = 0

    /// 超速警告信息
    var speedWarningMessage: String?

    // MARK: - 奖励等级相关属性

    /// 当前奖励等级（根据已走距离计算）
    var currentRewardTier: RewardTier {
        return RewardTier.fromDistance(totalDistance)
    }

    /// 距离下一等级还差多少米
    var distanceToNextTier: Double {
        return RewardTier.distanceToNextTier(currentDistance: totalDistance)
    }

    /// 下一等级的名称（如果有）
    var nextTierName: String? {
        return currentRewardTier.nextTier?.displayName
    }

    // MARK: - POI 相关属性

    /// 附近 POI 列表（存储属性，确保 SwiftUI 能观察到变化）
    var nearbyPOIs: [ScavengePOI] = []

    /// 当前接近的 POI（50米内）
    var approachingPOI: ScavengePOI?

    /// 是否显示 POI 搜刮弹窗
    var showScavengePopup: Bool = false

    /// 弹窗中的 POI
    var popupPOI: ScavengePOI?

    /// 是否正在搜刮
    var isScavenging: Bool = false

    /// 最近一次搜刮的结果
    var scavengeResult: [RewardedItem]?

    /// POI 更新版本号（用于触发 UI 刷新）
    var poiUpdateVersion: Int = 0

    // MARK: - Private Properties

    /// 位置管理器
    private var locationManager: CLLocationManager?

    /// 上一个有效位置
    private var lastValidLocation: CLLocation?

    /// 计时器
    private var timer: Timer?

    /// 探索开始时间
    private var startTime: Date?

    /// Supabase 服务
    private let supabaseService = SupabaseService.shared

    // MARK: - Constants

    /// 位置精度阈值（米）
    private let accuracyThreshold: Double = 50

    /// 距离跳变阈值（米）
    private let distanceJumpThreshold: Double = 100

    /// 最小位置更新间隔（秒）
    private let minUpdateInterval: TimeInterval = 1.0

    /// 速度限制（km/h）
    private let speedLimit: Double = 20.0

    /// 超速容忍时间（秒）
    private let overSpeedTolerance: TimeInterval = 10.0

    // MARK: - 速度相关私有属性

    /// 超速开始时间
    private var overSpeedStartTime: Date?

    /// 超速检测定时器
    private var overSpeedTimer: Timer?

    /// 上一次的速度值（用于日志）
    private var lastSpeedLog: Double = 0

    // MARK: - 地理围栏相关私有属性

    /// 已监控的围栏 ID 列表（最多20个）
    private var monitoredRegionIds: Set<String> = []

    /// 围栏半径（米）
    private let geofenceRadius: CLLocationDistance = 50

    // MARK: - Init

    private override init() {
        super.init()
        setupLocationManager()
    }

    // MARK: - Setup

    private func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        locationManager?.distanceFilter = 5 // 每移动5米更新一次
        locationManager?.allowsBackgroundLocationUpdates = false
        locationManager?.pausesLocationUpdatesAutomatically = false
    }

    // MARK: - Public Methods

    /// 开始探索
    func startExploration() async throws {
        print("🔍 [探索] 开始探索请求...")
        print("🔍 [探索] 当前状态: \(state)")

        guard state == .idle || state == .completed || (state != .exploring && state != .finishing) else {
            print("❌ [探索] 无法开始: 当前已在探索中")
            throw ExplorationError.alreadyExploring
        }

        // 如果是失败状态，也允许重新开始
        if case .failed = state {
            print("🔄 [探索] 从失败状态恢复，允许重新开始")
        }

        // 请求位置权限
        let authStatus = locationManager?.authorizationStatus ?? .notDetermined
        print("📍 [探索] 当前授权状态: \(authStatus.rawValue)")

        if authStatus == .notDetermined {
            print("📍 [探索] 请求位置权限...")
            locationManager?.requestWhenInUseAuthorization()
            // 等待授权结果
            try await Task.sleep(nanoseconds: 500_000_000)
        }

        guard authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways else {
            print("❌ [探索] 位置权限未授权")
            throw ExplorationError.locationNotAuthorized
        }

        // 重置状态
        resetState()

        // 获取当前位置
        let currentLocation = locationManager?.location
        startCoordinate = currentLocation?.coordinate
        currentCoordinate = startCoordinate
        lastValidLocation = currentLocation

        if let coord = startCoordinate {
            print("📍 [探索] 起始位置: (\(String(format: "%.6f", coord.latitude)), \(String(format: "%.6f", coord.longitude)))")
        } else {
            print("⚠️ [探索] 起始位置未知，将在首次位置更新时记录")
        }

        // 创建数据库记录
        do {
            let session = try await supabaseService.createExplorationSession(
                startLat: startCoordinate?.latitude,
                startLng: startCoordinate?.longitude
            )
            currentSessionId = session.id
            print("✅ [探索] 创建探索记录成功，ID: \(session.id)")
        } catch {
            print("❌ [探索] 创建探索记录失败: \(error.localizedDescription)")
            throw ExplorationError.databaseError(error.localizedDescription)
        }

        // 开始位置追踪
        startTime = Date()
        state = .exploring
        locationManager?.startUpdatingLocation()
        startTimer()

        print("🚶 [探索] ========== 探索已开始 ==========")
        print("🚶 [探索] 速度限制: \(Int(speedLimit))km/h")
        print("🚶 [探索] 超速容忍时间: \(Int(overSpeedTolerance))秒")
    }

    /// 结束探索
    func stopExploration() async throws -> ExplorationResult {
        print("🛑 [探索] 收到结束探索请求...")
        print("🛑 [探索] 当前状态: \(state)")

        guard state == .exploring else {
            print("❌ [探索] 无法结束: 当前未在探索中")
            throw ExplorationError.notExploring
        }

        state = .finishing
        print("🛑 [探索] 状态变更为: finishing")

        // 停止位置追踪
        locationManager?.stopUpdatingLocation()
        stopTimer()
        stopOverSpeedTimer()

        // 计算最终数据
        let finalDuration = duration
        let finalDistance = totalDistance
        let endCoordinate = currentCoordinate

        print("📊 [探索] ========== 探索统计 ==========")
        print("📊 [探索] 总距离: \(String(format: "%.1f", finalDistance))m")
        print("📊 [探索] 总时长: \(finalDuration)秒 (\(finalDuration / 60)分\(finalDuration % 60)秒)")
        if let startCoord = startCoordinate, let endCoord = endCoordinate {
            print("📊 [探索] 起点: (\(String(format: "%.6f", startCoord.latitude)), \(String(format: "%.6f", startCoord.longitude)))")
            print("📊 [探索] 终点: (\(String(format: "%.6f", endCoord.latitude)), \(String(format: "%.6f", endCoord.longitude)))")
        }

        // 计算奖励等级
        let rewardTier = RewardTier.fromDistance(finalDistance)
        print("🏆 [探索] 奖励等级: \(rewardTier.displayName)")

        // 生成奖励物品
        var rewardedItems: [RewardedItem] = []
        if rewardTier != .none {
            print("🎁 [探索] 开始生成奖励...")
            rewardedItems = try await RewardGenerator.shared.generateRewards(
                tier: rewardTier
            )
            print("🎁 [探索] 生成了 \(rewardedItems.count) 种奖励物品")
        } else {
            print("💨 [探索] 距离不足，无奖励")
        }

        // 更新数据库记录
        if let sessionId = currentSessionId {
            do {
                try await supabaseService.updateExplorationSession(
                    sessionId: sessionId,
                    endLat: endCoordinate?.latitude,
                    endLng: endCoordinate?.longitude,
                    totalDistance: finalDistance,
                    duration: finalDuration,
                    rewardTier: rewardTier,
                    itemsRewarded: rewardedItems
                )
                print("✅ [探索] 更新探索记录成功")

                // 添加物品到背包
                if !rewardedItems.isEmpty {
                    try await supabaseService.addItemsToInventory(items: rewardedItems)
                    print("🎒 [探索] 物品已添加到背包，共 \(rewardedItems.count) 种")
                }
            } catch {
                print("❌ [探索] 更新探索记录失败: \(error.localizedDescription)")
                // 继续返回结果，不阻断流程
            }
        }

        // 获取累计数据
        var totalStats: (totalDistance: Double, totalDuration: Int, sessionCount: Int) = (0, 0, 0)
        if let userId = supabaseService.currentUserId {
            do {
                totalStats = try await supabaseService.getExplorationStats(userId: userId)
                print("📈 [探索] 历史累计距离: \(String(format: "%.1f", totalStats.totalDistance))m")
            } catch {
                print("⚠️ [探索] 获取累计数据失败: \(error.localizedDescription)")
            }
        }

        state = .completed
        print("✅ [探索] 状态变更为: completed")

        // 创建结果
        let result = ExplorationResult(
            sessionId: currentSessionId ?? UUID(),
            distance: finalDistance,
            duration: finalDuration,
            rewardTier: rewardTier,
            rewardedItems: rewardedItems,
            startCoordinate: startCoordinate,
            endCoordinate: endCoordinate,
            totalDistance: totalStats.totalDistance + finalDistance,
            totalDuration: totalStats.totalDuration + finalDuration
        )

        print("🏁 [探索] ========== 探索完成 ==========")
        print("🏁 [探索] 距离: \(String(format: "%.1f", finalDistance))m, 时长: \(finalDuration)s, 等级: \(rewardTier.displayName)")

        return result
    }

    /// 取消探索
    func cancelExploration() async {
        guard state == .exploring else { return }

        // 停止追踪
        locationManager?.stopUpdatingLocation()
        stopTimer()

        // 取消数据库记录
        if let sessionId = currentSessionId {
            do {
                try await supabaseService.cancelExplorationSession(sessionId: sessionId)
                print("🚫 [探索] 探索已取消")
            } catch {
                print("⚠️ [探索] 取消探索记录失败: \(error.localizedDescription)")
            }
        }

        resetState()
    }

    /// 重置状态
    func reset() {
        resetState()
    }

    // MARK: - POI 搜索和围栏管理方法

    /// 搜索附近 POI 并设置围栏
    func searchNearbyPOIs() async {
        guard let coordinate = currentCoordinate else {
            print("⚠️ [探索] 无法搜索 POI：位置未知")
            return
        }

        print("🔍 [探索] 开始搜索附近 POI...")
        await POISearchManager.shared.searchNearbyPOIs(center: coordinate, forceRefresh: true)

        // 复制 POI 到存储属性（确保 SwiftUI 观察到变化）
        nearbyPOIs = POISearchManager.shared.pois

        // 为 POI 设置地理围栏
        setupGeofences(for: nearbyPOIs)

        // 触发 UI 更新
        poiUpdateVersion += 1

        print("📍 [探索] POI 已更新到视图，共 \(nearbyPOIs.count) 个")
    }

    /// 设置地理围栏
    private func setupGeofences(for pois: [ScavengePOI]) {
        // 清除旧围栏
        clearAllGeofences()

        // iOS 限制最多同时监控 20 个区域
        let poisToMonitor = Array(pois.prefix(20))

        for poi in poisToMonitor {
            let region = CLCircularRegion(
                center: poi.coordinate,
                radius: geofenceRadius,
                identifier: poi.id
            )
            region.notifyOnEntry = true
            region.notifyOnExit = false

            locationManager?.startMonitoring(for: region)
            monitoredRegionIds.insert(poi.id)
        }

        print("📍 [探索] 已设置 \(poisToMonitor.count) 个地理围栏")
    }

    /// 清除所有地理围栏
    private func clearAllGeofences() {
        guard let manager = locationManager else { return }

        for region in manager.monitoredRegions {
            if let circular = region as? CLCircularRegion,
               monitoredRegionIds.contains(circular.identifier) {
                manager.stopMonitoring(for: region)
            }
        }

        monitoredRegionIds.removeAll()
        print("📍 [探索] 已清除所有地理围栏")
    }

    /// 处理进入围栏（在 CLLocationManagerDelegate 中调用）
    func handleEnterRegion(identifier: String) {
        // 防止重复弹窗：如果已有弹窗显示中，忽略
        guard !showScavengePopup else {
            print("⚠️ [探索] 弹窗已显示，忽略进入围栏: \(identifier)")
            return
        }

        // 防止搜刮中再次弹窗
        guard !isScavenging else {
            print("⚠️ [探索] 正在搜刮中，忽略进入围栏: \(identifier)")
            return
        }

        // 查找对应的 POI
        guard let poi = nearbyPOIs.first(where: { $0.id == identifier }),
              poi.canScavenge else {
            print("⚠️ [探索] 进入围栏但 POI 不可搜刮: \(identifier)")
            return
        }

        // 设置接近的 POI
        approachingPOI = poi
        popupPOI = poi

        // 显示弹窗
        showScavengePopup = true

        // 触发震动提示
        triggerApproachHaptic()

        print("🎯 [探索] 进入 POI 围栏: \(poi.name)")
    }

    /// 触发接近震动
    private func triggerApproachHaptic() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
        #endif
    }

    // MARK: - 搜刮方法

    /// 执行搜刮
    func scavengePOI(_ poi: ScavengePOI) async throws -> [RewardedItem] {
        guard poi.canScavenge else {
            throw ScavengeError.notInRange
        }

        isScavenging = true
        print("🔍 [探索] 开始搜刮: \(poi.name)")

        // 模拟搜刮动画延迟
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5秒

        // 生成奖励
        let rewards = try await generateScavengeRewards(tier: poi.rewardTier)

        // 添加到背包
        if !rewards.isEmpty {
            try await supabaseService.addItemsToInventory(items: rewards)
            print("🎒 [探索] 搜刮物品已添加到背包，共 \(rewards.count) 种")
        }

        // 标记 POI 为已搜刮（同时更新两边）
        POISearchManager.shared.markAsScavenged(poiId: poi.id)

        // 更新本地存储的 POI 状态
        if let index = nearbyPOIs.firstIndex(where: { $0.id == poi.id }) {
            nearbyPOIs[index].status = .depleted
            nearbyPOIs[index].lastScavengedAt = Date()
        }

        // 触发 UI 更新
        poiUpdateVersion += 1

        isScavenging = false
        scavengeResult = rewards

        print("✅ [探索] 搜刮完成，获得 \(rewards.count) 种物品")

        return rewards
    }

    /// 根据 POI 类型生成搜刮奖励
    private func generateScavengeRewards(tier: ScavengeTier) async throws -> [RewardedItem] {
        // 确保物品定义已加载
        await RewardGenerator.shared.preloadCache()

        // 物品数量 1-3 个
        let itemCount = Int.random(in: 1...3)
        var rewards: [RewardedItem] = []

        // 获取所有物品定义
        let allItems = RewardGenerator.shared.getAllItemDefinitions()

        for _ in 0..<itemCount {
            // 根据权重随机选择分类
            let category = selectCategory(from: tier.categoryWeights)

            // 随机稀有度
            let rarity = randomRarity()

            // 从该分类中随机选择物品
            if let item = selectItemFromCategory(items: allItems, category: category, rarity: rarity) {
                let quality: DBItemQuality? = item.hasQuality ? DBItemQuality.random() : nil
                let quantity = item.rarity == .common ? Int.random(in: 1...3) : 1

                rewards.append(RewardedItem(
                    itemId: item.id,
                    quantity: quantity,
                    quality: quality
                ))
            }
        }

        return rewards
    }

    /// 根据权重选择分类
    private func selectCategory(from weights: [(DBItemCategory, Double)]) -> DBItemCategory {
        let total = weights.reduce(0) { $0 + $1.1 }
        var random = Double.random(in: 0..<total)

        for (category, weight) in weights {
            random -= weight
            if random <= 0 {
                return category
            }
        }

        return weights.first?.0 ?? .misc
    }

    /// 随机稀有度
    private func randomRarity() -> DBItemRarity {
        let roll = Double.random(in: 0..<100)
        switch roll {
        case ..<60: return .common
        case ..<85: return .uncommon
        case ..<95: return .rare
        case ..<99: return .epic
        default: return .legendary
        }
    }

    /// 从分类中选择物品
    private func selectItemFromCategory(items: [DBItemDefinition], category: DBItemCategory, rarity: DBItemRarity) -> DBItemDefinition? {
        let filteredItems = items.filter { $0.category == category && $0.rarity == rarity }

        // 如果没有完全匹配的，放宽稀有度要求
        if filteredItems.isEmpty {
            let categoryItems = items.filter { $0.category == category }
            return categoryItems.randomElement()
        }

        return filteredItems.randomElement()
    }

    // MARK: - Private Methods

    private func resetState() {
        state = .idle
        totalDistance = 0
        duration = 0
        currentSessionId = nil
        startCoordinate = nil
        currentCoordinate = nil
        lastValidLocation = nil
        startTime = nil
        // 重置速度相关状态
        currentSpeed = 0
        overSpeedState = .normal
        overSpeedRemainingSeconds = 0
        speedWarningMessage = nil
        overSpeedStartTime = nil
        stopOverSpeedTimer()
        lastSpeedLog = 0
        // 重置 POI 相关状态
        clearAllGeofences()
        POISearchManager.shared.clearPOIs()
        nearbyPOIs = []
        showScavengePopup = false
        popupPOI = nil
        approachingPOI = nil
        isScavenging = false
        scavengeResult = nil
        poiUpdateVersion = 0
        print("🔄 [探索] 状态已重置")
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                self?.duration += 1
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    /// 停止超速检测定时器
    private func stopOverSpeedTimer() {
        overSpeedTimer?.invalidate()
        overSpeedTimer = nil
    }

    /// 处理速度更新
    private func handleSpeedUpdate(speed: Double) {
        let speedKmh = max(0, speed * 3.6) // m/s 转换为 km/h，负值表示无效
        let previousSpeed = currentSpeed
        currentSpeed = speedKmh

        // 速度变化日志（每 5km/h 变化记录一次）
        if abs(speedKmh - lastSpeedLog) >= 5 {
            print("⚡ [探索] 速度变化: \(String(format: "%.1f", lastSpeedLog))km/h → \(String(format: "%.1f", speedKmh))km/h")
            lastSpeedLog = speedKmh
        }

        // 检查是否超速
        if speedKmh > speedLimit {
            handleOverSpeed(currentSpeedKmh: speedKmh)
        } else {
            handleNormalSpeed(currentSpeedKmh: speedKmh, previousSpeedKmh: previousSpeed)
        }
    }

    /// 处理超速状态
    private func handleOverSpeed(currentSpeedKmh: Double) {
        if overSpeedState == .normal {
            // 首次超速，记录开始时间
            overSpeedStartTime = Date()
            overSpeedState = .warning
            overSpeedRemainingSeconds = Int(overSpeedTolerance)
            speedWarningMessage = "速度过快！请减速至\(Int(speedLimit))km/h以下"
            print("⚠️ [探索] 超速警告: 当前速度 \(String(format: "%.1f", currentSpeedKmh))km/h, 限制 \(Int(speedLimit))km/h")
            print("⏱️ [探索] 超速倒计时开始: \(Int(overSpeedTolerance))秒")

            // 启动超速倒计时定时器
            startOverSpeedTimer()
        } else if overSpeedState == .warning {
            // 持续超速，检查是否超时
            if let startTime = overSpeedStartTime {
                let elapsed = Date().timeIntervalSince(startTime)
                overSpeedRemainingSeconds = max(0, Int(overSpeedTolerance - elapsed))

                if elapsed >= overSpeedTolerance {
                    // 超速超过容忍时间，自动停止探索
                    print("🛑 [探索] 超速停止: 持续超速\(Int(elapsed))秒，探索自动终止")
                    Task {
                        await stopExplorationDueToOverSpeed()
                    }
                }
            }
        }
    }

    /// 处理正常速度状态
    private func handleNormalSpeed(currentSpeedKmh: Double, previousSpeedKmh: Double) {
        if overSpeedState == .warning {
            // 从超速恢复到正常
            print("✅ [探索] 速度恢复正常: \(String(format: "%.1f", currentSpeedKmh))km/h")
            overSpeedState = .normal
            overSpeedStartTime = nil
            overSpeedRemainingSeconds = 0
            speedWarningMessage = nil
            stopOverSpeedTimer()
        }
    }

    /// 启动超速倒计时定时器
    private func startOverSpeedTimer() {
        stopOverSpeedTimer()

        overSpeedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                await self.handleOverSpeedTimerTick()
            }
        }
    }

    /// 处理超速定时器回调
    private func handleOverSpeedTimerTick() async {
        guard overSpeedState == .warning else {
            stopOverSpeedTimer()
            return
        }

        if let startTime = overSpeedStartTime {
            let elapsed = Date().timeIntervalSince(startTime)
            overSpeedRemainingSeconds = max(0, Int(overSpeedTolerance - elapsed))

            if overSpeedRemainingSeconds > 0 {
                print("⏱️ [探索] 超速倒计时: \(overSpeedRemainingSeconds)秒")
            }

            if elapsed >= overSpeedTolerance {
                print("🛑 [探索] 超速停止: 倒计时结束，探索自动终止")
                await stopExplorationDueToOverSpeed()
            }
        }
    }

    /// 因超速停止探索
    private func stopExplorationDueToOverSpeed() async {
        guard state == .exploring else { return }

        // 停止位置追踪
        locationManager?.stopUpdatingLocation()
        stopTimer()
        stopOverSpeedTimer()

        // 设置超速停止状态
        overSpeedState = .stopped
        speedWarningMessage = "速度过快，探索已自动终止"

        // 取消数据库记录
        if let sessionId = currentSessionId {
            do {
                try await supabaseService.cancelExplorationSession(sessionId: sessionId)
                print("🚫 [探索] 超速终止，探索记录已取消")
            } catch {
                print("⚠️ [探索] 取消探索记录失败: \(error.localizedDescription)")
            }
        }

        // 设置失败状态
        state = .failed("速度过快，探索已自动终止。请步行探索，速度不要超过20km/h。")
        print("❌ [探索] 探索因超速失败")
    }

    /// 计算两点间距离（米）
    private func calculateDistance(from: CLLocation, to: CLLocation) -> Double {
        return to.distance(from: from)
    }

    /// 验证位置有效性
    private func isValidLocation(_ location: CLLocation) -> Bool {
        // 检查精度
        if location.horizontalAccuracy > accuracyThreshold {
            print("⚠️ [探索] 位置精度太差: \(location.horizontalAccuracy)m")
            return false
        }

        // 检查与上一个位置的距离跳变
        if let lastLocation = lastValidLocation {
            let distance = calculateDistance(from: lastLocation, to: location)
            if distance > distanceJumpThreshold {
                print("⚠️ [探索] 位置跳变过大: \(distance)m")
                return false
            }

            // 检查时间间隔
            let timeInterval = location.timestamp.timeIntervalSince(lastLocation.timestamp)
            if timeInterval < minUpdateInterval {
                return false
            }
        }

        return true
    }
}

// MARK: - CLLocationManagerDelegate
extension ExplorationManager: CLLocationManagerDelegate {

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard state == .exploring else { return }

            for location in locations {
                // 详细位置日志
                let speedKmh = max(0, location.speed * 3.6)
                print("📍 [探索] 位置更新: (\(String(format: "%.6f", location.coordinate.latitude)), \(String(format: "%.6f", location.coordinate.longitude))), 精度: \(String(format: "%.1f", location.horizontalAccuracy))m, 速度: \(String(format: "%.1f", speedKmh))km/h")

                // 处理速度（不管位置是否有效都要检测速度）
                handleSpeedUpdate(speed: location.speed)

                // 如果正在超速，不累计距离
                if overSpeedState == .warning || overSpeedState == .stopped {
                    print("⚠️ [探索] 超速中，跳过距离累计")
                    continue
                }

                // 验证位置有效性
                guard isValidLocation(location) else { continue }

                // 更新当前坐标
                currentCoordinate = location.coordinate

                // 计算与上一个有效位置的距离
                if let lastLocation = lastValidLocation {
                    let distance = calculateDistance(from: lastLocation, to: location)
                    totalDistance += distance
                    print("🚶 [探索] 距离累加: +\(String(format: "%.1f", distance))m, 总计: \(String(format: "%.1f", totalDistance))m")
                }

                lastValidLocation = location
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            print("❌ [探索] 位置更新失败: \(error.localizedDescription)")
            // 如果是位置服务不可用，可能需要处理
            if let clError = error as? CLError {
                print("❌ [探索] CLError 代码: \(clError.code.rawValue)")
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            print("📍 [探索] 授权状态变更: \(manager.authorizationStatus.rawValue)")
        }
    }

    /// 进入地理围栏
    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        Task { @MainActor in
            guard state == .exploring else { return }

            print("📍 [探索] 进入区域: \(region.identifier)")
            handleEnterRegion(identifier: region.identifier)
        }
    }

    /// 围栏监控失败
    nonisolated func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        Task { @MainActor in
            print("❌ [探索] 围栏监控失败: \(region?.identifier ?? "unknown") - \(error.localizedDescription)")
        }
    }

    /// 开始监控区域
    nonisolated func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        Task { @MainActor in
            print("📍 [探索] 开始监控区域: \(region.identifier)")
        }
    }
}

// MARK: - Exploration Error
enum ExplorationError: LocalizedError {
    case alreadyExploring
    case notExploring
    case locationNotAuthorized
    case databaseError(String)
    case overSpeedStopped  // 超速停止

    var errorDescription: String? {
        switch self {
        case .alreadyExploring:
            return "已经在探索中"
        case .notExploring:
            return "当前没有进行探索"
        case .locationNotAuthorized:
            return "未授权位置权限"
        case .databaseError(let message):
            return "数据库错误: \(message)"
        case .overSpeedStopped:
            return "速度过快，探索已自动终止"
        }
    }
}

// MARK: - Exploration Result
struct ExplorationResult {
    let sessionId: UUID
    let distance: Double           // 本次距离（米）
    let duration: Int              // 本次时长（秒）
    let rewardTier: RewardTier     // 奖励等级
    let rewardedItems: [RewardedItem]  // 获得的物品
    let startCoordinate: CLLocationCoordinate2D?
    let endCoordinate: CLLocationCoordinate2D?
    let totalDistance: Double      // 累计距离
    let totalDuration: Int         // 累计时长

    /// 格式化距离
    var formattedDistance: String {
        if distance >= 1000 {
            return String(format: "%.2f km", distance / 1000)
        } else {
            return String(format: "%.0f m", distance)
        }
    }

    /// 格式化时长
    var formattedDuration: String {
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

    /// 格式化累计距离
    var formattedTotalDistance: String {
        if totalDistance >= 1000 {
            return String(format: "%.2f km", totalDistance / 1000)
        } else {
            return String(format: "%.0f m", totalDistance)
        }
    }
}

// MARK: - Scavenge Error

/// 搜刮错误
enum ScavengeError: LocalizedError {
    case notInRange
    case alreadyScavenged
    case noRewardsGenerated

    var errorDescription: String? {
        switch self {
        case .notInRange:
            return "距离太远，无法搜刮"
        case .alreadyScavenged:
            return "该地点已被搜刮"
        case .noRewardsGenerated:
            return "搜刮失败，未找到物资"
        }
    }
}
