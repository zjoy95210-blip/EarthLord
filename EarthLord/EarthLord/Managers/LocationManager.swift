//
//  LocationManager.swift
//  EarthLord
//
//  GPS 定位管理器 - 处理用户位置获取、权限管理、路径追踪和速度检测
//

import Foundation
import CoreLocation
import Combine
import UIKit

// MARK: - LocationManager
@MainActor
final class LocationManager: NSObject, ObservableObject {

    // MARK: - Singleton
    static let shared = LocationManager()

    // MARK: - Published Properties

    /// 用户当前位置坐标
    @Published var userLocation: CLLocationCoordinate2D?

    /// 定位授权状态
    @Published var authorizationStatus: CLAuthorizationStatus

    /// 定位错误信息
    @Published var locationError: String?

    /// 是否正在定位
    @Published var isUpdatingLocation: Bool = false

    // MARK: - 路径追踪属性

    /// 是否正在追踪路径
    @Published var isTracking: Bool = false

    /// 路径坐标数组（存储原始 WGS-84 坐标）
    @Published var pathCoordinates: [CLLocationCoordinate2D] = []

    /// 路径更新版本号（用于触发 SwiftUI 更新）
    @Published var pathUpdateVersion: Int = 0

    /// 路径是否闭合
    @Published var isPathClosed: Bool = false

    // MARK: - 速度检测属性

    /// 速度警告信息
    @Published var speedWarning: String?

    /// 是否超速
    @Published var isOverSpeed: Bool = false

    /// 当前速度 (km/h)
    @Published var currentSpeed: Double = 0

    // MARK: - 验证状态属性

    /// 领地验证是否通过
    @Published var territoryValidationPassed: Bool = false

    /// 领地验证错误信息
    @Published var territoryValidationError: String? = nil

    /// 计算出的领地面积（平方米）
    @Published var calculatedArea: Double = 0

    // MARK: - 闭环检测常量

    /// 闭环距离阈值（米）
    private let closureDistanceThreshold: Double = 30.0

    /// 最少路径点数（需要至少这么多点才检测闭环）
    private let minimumPathPoints: Int = 10

    // MARK: - 验证常量

    /// 最小行走距离（米）
    private let minimumTotalDistance: Double = 50.0

    /// 最小领地面积（平方米）
    private let minimumEnclosedArea: Double = 100.0

    // MARK: - 速度检测常量

    /// 警告速度阈值 (km/h)
    private let warningSpeedThreshold: Double = 15.0

    /// 停止速度阈值 (km/h)
    private let stopSpeedThreshold: Double = 30.0

    // MARK: - Private Properties

    /// CoreLocation 管理器
    private let locationManager: CLLocationManager

    /// 当前位置（用于 Timer 采点）
    private var currentLocation: CLLocation?

    /// 采点定时器
    private var pathUpdateTimer: Timer?

    /// 最小采点距离（米）
    private let minimumPathDistance: Double = 10.0

    /// 采点时间间隔（秒）
    private let pathUpdateInterval: TimeInterval = 2.0

    /// 上次记录路径点的位置（用于速度计算）
    private var lastPathLocation: CLLocation?

    /// 上次记录路径点的时间戳
    private var lastPathTimestamp: Date?

    // MARK: - Computed Properties

    /// 是否已授权定位
    var isAuthorized: Bool {
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        default:
            return false
        }
    }

    /// 是否被拒绝定位
    var isDenied: Bool {
        authorizationStatus == .denied
    }

    /// 是否尚未决定
    var isNotDetermined: Bool {
        authorizationStatus == .notDetermined
    }

    /// 路径点数量
    var pathPointCount: Int {
        pathCoordinates.count
    }

    // MARK: - Initialization

    override private init() {
        self.locationManager = CLLocationManager()
        self.authorizationStatus = locationManager.authorizationStatus

        super.init()

        // 配置定位管理器
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5  // 移动5米就更新（追踪时需要更精细）

        print("📍 [定位] LocationManager 初始化完成")
        print("📍 [定位] 当前授权状态: \(authorizationStatusString)")
    }

    // MARK: - Public Methods

    /// 请求定位权限
    func requestPermission() {
        print("📍 [定位] 请求定位权限...")
        locationManager.requestWhenInUseAuthorization()
    }

    /// 开始更新位置
    func startUpdatingLocation() {
        guard isAuthorized else {
            print("❌ [定位] 未授权，无法开始定位")
            locationError = "未授权定位权限"
            return
        }

        print("📍 [定位] 开始更新位置...")
        isUpdatingLocation = true
        locationError = nil
        locationManager.startUpdatingLocation()
    }

    /// 停止更新位置
    func stopUpdatingLocation() {
        print("📍 [定位] 停止更新位置")
        isUpdatingLocation = false
        locationManager.stopUpdatingLocation()
    }

    /// 请求单次位置更新
    func requestLocation() {
        guard isAuthorized else {
            print("❌ [定位] 未授权，无法请求位置")
            locationError = "未授权定位权限"
            return
        }

        print("📍 [定位] 请求单次位置...")
        locationError = nil
        locationManager.requestLocation()
    }

    /// 打开系统设置
    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    /// 清除速度警告
    func clearSpeedWarning() {
        speedWarning = nil
        isOverSpeed = false
    }

    // MARK: - 路径追踪方法

    /// 开始路径追踪
    func startPathTracking() {
        guard isAuthorized else {
            print("❌ [路径] 未授权，无法开始追踪")
            return
        }

        guard !isTracking else {
            print("⚠️ [路径] 已在追踪中")
            return
        }

        print("🚶 [路径] 开始路径追踪")
        TerritoryLogger.shared.log("开始圈地追踪", type: .info)

        // 清除旧路径
        clearPath()

        // 清除速度警告
        clearSpeedWarning()

        // 重置速度检测状态
        lastPathLocation = nil
        lastPathTimestamp = nil
        currentSpeed = 0

        // 设置追踪状态
        isTracking = true

        // 确保定位正在运行
        if !isUpdatingLocation {
            startUpdatingLocation()
        }

        // 如果有当前位置，记录第一个点
        if let location = currentLocation {
            recordPathPoint(from: location)
        }

        // 启动定时器，每 2 秒检查一次
        pathUpdateTimer = Timer.scheduledTimer(withTimeInterval: pathUpdateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.timerFired()
            }
        }

        print("⏱️ [路径] 采点定时器已启动，间隔: \(pathUpdateInterval)秒")
    }

    /// 停止路径追踪
    func stopPathTracking() {
        guard isTracking else {
            print("⚠️ [路径] 当前未在追踪")
            return
        }

        print("🛑 [路径] 停止路径追踪")
        TerritoryLogger.shared.log("停止追踪，共 \(pathCoordinates.count) 个点", type: .info)

        // 停止定时器
        pathUpdateTimer?.invalidate()
        pathUpdateTimer = nil

        // 更新状态
        isTracking = false

        // 最终检查路径是否闭合
        checkPathClosure()

        print("📊 [路径] 最终路径点数: \(pathCoordinates.count)")
    }

    /// 清除路径
    func clearPath() {
        print("🗑️ [路径] 清除路径")
        pathCoordinates.removeAll()
        pathUpdateVersion += 1
        isPathClosed = false

        // 重置验证状态
        territoryValidationPassed = false
        territoryValidationError = nil
        calculatedArea = 0
    }

    // MARK: - Private Methods

    /// 定时器触发时的处理
    private func timerFired() {
        guard isTracking, let location = currentLocation else {
            return
        }

        recordPathPoint(from: location)
    }

    /// 记录路径点
    /// - Parameter location: 当前位置
    private func recordPathPoint(from location: CLLocation) {
        // ⭐ 先进行速度检测
        if !validateMovementSpeed(newLocation: location) {
            // 超速，不记录该点
            return
        }

        let newCoordinate = location.coordinate

        // 检查是否需要记录（与上一个点距离 > 10米）
        var distanceFromLast: Double = 0
        if let lastCoordinate = pathCoordinates.last {
            let lastLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
            distanceFromLast = location.distance(from: lastLocation)

            // 距离不足，跳过
            if distanceFromLast < minimumPathDistance {
                return
            }

            print("📍 [路径] 距离上点 \(String(format: "%.1f", distanceFromLast))米，记录新点")
        } else {
            print("📍 [路径] 记录第一个点")
        }

        // 记录坐标（保存原始 WGS-84）
        pathCoordinates.append(newCoordinate)

        // 更新上次位置和时间戳（用于下次速度计算）
        lastPathLocation = location
        lastPathTimestamp = Date()

        // 更新版本号触发 UI 刷新
        pathUpdateVersion += 1

        // 记录日志
        if pathCoordinates.count == 1 {
            TerritoryLogger.shared.log("记录第 1 个点", type: .info)
        } else {
            TerritoryLogger.shared.log("记录第 \(pathCoordinates.count) 个点，距上点 \(String(format: "%.1f", distanceFromLast))m", type: .info)
        }

        print("📍 [路径] 当前路径点数: \(pathCoordinates.count)")

        // ⭐ 每次添加新坐标后检查闭环
        checkPathClosure()
    }

    // MARK: - 闭环检测

    /// 检查路径是否闭合
    private func checkPathClosure() {
        // 已经闭合就不再检测
        guard !isPathClosed else { return }

        // 至少需要指定数量的点才检测闭环
        guard pathCoordinates.count >= minimumPathPoints else {
            print("🔄 [闭环] 点数不足，当前: \(pathCoordinates.count)，需要: \(minimumPathPoints)")
            return
        }

        // 检查当前位置到起点的距离
        guard let first = pathCoordinates.first,
              let last = pathCoordinates.last else {
            return
        }

        let firstLocation = CLLocation(latitude: first.latitude, longitude: first.longitude)
        let lastLocation = CLLocation(latitude: last.latitude, longitude: last.longitude)

        let distance = lastLocation.distance(from: firstLocation)

        print("🔄 [闭环] 检测中... 首尾距离: \(String(format: "%.1f", distance))米，阈值: \(closureDistanceThreshold)米")

        // 记录闭环检测日志
        TerritoryLogger.shared.log("距起点 \(String(format: "%.1f", distance))m (需≤\(Int(closureDistanceThreshold))m)", type: .info)

        // 距离小于阈值则闭合成功
        if distance <= closureDistanceThreshold {
            isPathClosed = true

            // 触发 UI 更新
            pathUpdateVersion += 1

            print("✅ [闭环] 闭环检测成功！首尾距离: \(String(format: "%.1f", distance))米")
            TerritoryLogger.shared.log("闭环成功！距起点 \(String(format: "%.1f", distance))m", type: .success)

            // ⭐ 闭环成功后进行综合验证
            let validationResult = validateTerritory()
            territoryValidationPassed = validationResult.isValid
            territoryValidationError = validationResult.errorMessage

            // 自动停止追踪
            if isTracking {
                print("🎉 [闭环] 自动停止追踪")
                stopPathTracking()
            }
        } else {
            print("⏳ [闭环] 尚未闭合，还需接近起点 \(String(format: "%.1f", distance - closureDistanceThreshold))米")
        }
    }

    // MARK: - 速度检测

    /// 验证移动速度
    /// - Parameter newLocation: 新位置
    /// - Returns: true 表示速度正常，false 表示超速
    private func validateMovementSpeed(newLocation: CLLocation) -> Bool {
        // 第一个点不检测速度
        guard let lastLocation = lastPathLocation,
              let lastTimestamp = lastPathTimestamp else {
            return true
        }

        // 计算距离（米）
        let distance = newLocation.distance(from: lastLocation)

        // 计算时间差（秒）
        let timeInterval = Date().timeIntervalSince(lastTimestamp)

        // 避免除零
        guard timeInterval > 0 else { return true }

        // 计算速度 (m/s → km/h)
        let speedMps = distance / timeInterval
        let speedKmh = speedMps * 3.6

        // 更新当前速度
        currentSpeed = speedKmh

        print("🏃 [速度] 当前速度: \(String(format: "%.1f", speedKmh)) km/h")

        // 检查是否超过停止阈值 (30 km/h)
        if speedKmh > stopSpeedThreshold {
            speedWarning = "速度过快 (\(String(format: "%.0f", speedKmh)) km/h)，追踪已暂停"
            isOverSpeed = true

            print("🚫 [速度] 严重超速！速度: \(String(format: "%.1f", speedKmh)) km/h，自动停止追踪")
            TerritoryLogger.shared.log("超速 \(String(format: "%.1f", speedKmh)) km/h，已停止追踪", type: .error)

            // 自动停止追踪
            stopPathTracking()

            // 3秒后清除警告
            scheduleWarningDismissal()

            return false
        }

        // 检查是否超过警告阈值 (15 km/h)
        if speedKmh > warningSpeedThreshold {
            speedWarning = "移动速度较快 (\(String(format: "%.0f", speedKmh)) km/h)，请步行"
            isOverSpeed = true

            print("⚠️ [速度] 速度警告！速度: \(String(format: "%.1f", speedKmh)) km/h")
            TerritoryLogger.shared.log("速度较快 \(String(format: "%.1f", speedKmh)) km/h", type: .warning)

            // 3秒后清除警告
            scheduleWarningDismissal()

            // 警告但仍记录该点
            return true
        }

        // 速度正常，清除警告状态
        if isOverSpeed {
            isOverSpeed = false
        }

        return true
    }

    /// 延迟清除速度警告
    private func scheduleWarningDismissal() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.speedWarning = nil
        }
    }

    /// 授权状态字符串（用于日志）
    private var authorizationStatusString: String {
        switch authorizationStatus {
        case .notDetermined:
            return "未决定"
        case .restricted:
            return "受限"
        case .denied:
            return "已拒绝"
        case .authorizedAlways:
            return "始终允许"
        case .authorizedWhenInUse:
            return "使用时允许"
        @unknown default:
            return "未知"
        }
    }

    // MARK: - 距离与面积计算

    /// 计算路径总距离
    /// - Returns: 总距离（米）
    private func calculateTotalPathDistance() -> Double {
        guard pathCoordinates.count >= 2 else { return 0 }

        var totalDistance: Double = 0

        for i in 0..<(pathCoordinates.count - 1) {
            let current = pathCoordinates[i]
            let next = pathCoordinates[i + 1]

            let currentLocation = CLLocation(latitude: current.latitude, longitude: current.longitude)
            let nextLocation = CLLocation(latitude: next.latitude, longitude: next.longitude)

            totalDistance += currentLocation.distance(from: nextLocation)
        }

        return totalDistance
    }

    /// 计算多边形面积（使用鞋带公式，考虑地球曲率）
    /// - Returns: 面积（平方米）
    private func calculatePolygonArea() -> Double {
        guard pathCoordinates.count >= 3 else { return 0 }

        let earthRadius: Double = 6371000  // 地球半径（米）
        var area: Double = 0

        for i in 0..<pathCoordinates.count {
            let current = pathCoordinates[i]
            let next = pathCoordinates[(i + 1) % pathCoordinates.count]  // 循环取点

            // 经纬度转弧度
            let lat1 = current.latitude * .pi / 180
            let lon1 = current.longitude * .pi / 180
            let lat2 = next.latitude * .pi / 180
            let lon2 = next.longitude * .pi / 180

            // 鞋带公式（球面修正）
            area += (lon2 - lon1) * (2 + sin(lat1) + sin(lat2))
        }

        area = abs(area * earthRadius * earthRadius / 2.0)

        return area
    }

    // MARK: - 自相交检测（CCW 算法）

    /// 判断两条线段是否相交（使用 CCW 算法）
    /// - Parameters:
    ///   - p1: 线段1起点
    ///   - p2: 线段1终点
    ///   - p3: 线段2起点
    ///   - p4: 线段2终点
    /// - Returns: true 表示相交
    private func segmentsIntersect(p1: CLLocationCoordinate2D, p2: CLLocationCoordinate2D,
                                   p3: CLLocationCoordinate2D, p4: CLLocationCoordinate2D) -> Bool {
        /// CCW（Counter-Clockwise）判断：三点是否逆时针排列
        /// 坐标映射：longitude = X轴，latitude = Y轴
        /// 叉积 = (Cy - Ay) × (Bx - Ax) - (By - Ay) × (Cx - Ax)
        func ccw(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D, _ c: CLLocationCoordinate2D) -> Bool {
            let crossProduct = (c.latitude - a.latitude) * (b.longitude - a.longitude) -
                               (b.latitude - a.latitude) * (c.longitude - a.longitude)
            return crossProduct > 0
        }

        // 判断逻辑：ccw(p1, p3, p4) ≠ ccw(p2, p3, p4) 且 ccw(p1, p2, p3) ≠ ccw(p1, p2, p4)
        return ccw(p1, p3, p4) != ccw(p2, p3, p4) && ccw(p1, p2, p3) != ccw(p1, p2, p4)
    }

    /// 检测路径是否有自相交（防止画"8"字形）
    /// - Returns: true 表示有自交
    func hasPathSelfIntersection() -> Bool {
        // ✅ 防御性检查：至少需要4个点才可能自交
        guard pathCoordinates.count >= 4 else { return false }

        // ✅ 创建路径快照的深拷贝，避免并发修改问题
        let pathSnapshot = Array(pathCoordinates)

        // ✅ 再次检查快照是否有效
        guard pathSnapshot.count >= 4 else { return false }

        let segmentCount = pathSnapshot.count - 1

        // ✅ 防御性检查：确保有足够的线段
        guard segmentCount >= 2 else { return false }

        // ✅ 闭环时需要跳过的首尾线段数量（防止正常圈地被误判）
        let skipHeadCount = 2
        let skipTailCount = 2

        for i in 0..<segmentCount {
            // ✅ 循环内索引检查
            guard i < pathSnapshot.count - 1 else { break }

            let p1 = pathSnapshot[i]
            let p2 = pathSnapshot[i + 1]

            let startJ = i + 2
            guard startJ < segmentCount else { continue }

            for j in startJ..<segmentCount {
                // ✅ 循环内索引检查
                guard j < pathSnapshot.count - 1 else { break }

                // ✅ 跳过首尾附近线段的比较（防止正常闭环被误判为自交）
                let isHeadSegment = i < skipHeadCount
                let isTailSegment = j >= segmentCount - skipTailCount

                if isHeadSegment && isTailSegment {
                    continue
                }

                let p3 = pathSnapshot[j]
                let p4 = pathSnapshot[j + 1]

                if segmentsIntersect(p1: p1, p2: p2, p3: p3, p4: p4) {
                    TerritoryLogger.shared.log("自交检测: 线段\(i)-\(i+1) 与 线段\(j)-\(j+1) 相交", type: .error)
                    return true
                }
            }
        }

        TerritoryLogger.shared.log("自交检测: 无交叉 ✓", type: .info)
        return false
    }

    // MARK: - 综合验证

    /// 综合验证领地是否有效
    /// - Returns: (isValid: 是否有效, errorMessage: 错误信息)
    func validateTerritory() -> (isValid: Bool, errorMessage: String?) {
        TerritoryLogger.shared.log("开始领地验证", type: .info)

        // 1. 点数检查
        let pointCount = pathCoordinates.count
        if pointCount < minimumPathPoints {
            let error = "点数不足: \(pointCount)个 (需≥\(minimumPathPoints)个)"
            TerritoryLogger.shared.log("点数检查: \(error)", type: .error)
            TerritoryLogger.shared.log("领地验证失败: \(error)", type: .error)
            return (false, error)
        }
        TerritoryLogger.shared.log("点数检查: \(pointCount)个点 ✓", type: .info)

        // 2. 距离检查
        let totalDistance = calculateTotalPathDistance()
        if totalDistance < minimumTotalDistance {
            let error = "距离不足: \(String(format: "%.0f", totalDistance))m (需≥\(Int(minimumTotalDistance))m)"
            TerritoryLogger.shared.log("距离检查: \(error)", type: .error)
            TerritoryLogger.shared.log("领地验证失败: \(error)", type: .error)
            return (false, error)
        }
        TerritoryLogger.shared.log("距离检查: \(String(format: "%.0f", totalDistance))m ✓", type: .info)

        // 3. 自交检测
        if hasPathSelfIntersection() {
            let error = "轨迹自相交，请勿画8字形"
            TerritoryLogger.shared.log("领地验证失败: \(error)", type: .error)
            return (false, error)
        }

        // 4. 面积检查
        let area = calculatePolygonArea()
        calculatedArea = area  // 保存计算结果
        if area < minimumEnclosedArea {
            let error = "面积不足: \(String(format: "%.0f", area))m² (需≥\(Int(minimumEnclosedArea))m²)"
            TerritoryLogger.shared.log("面积检查: \(error)", type: .error)
            TerritoryLogger.shared.log("领地验证失败: \(error)", type: .error)
            return (false, error)
        }
        TerritoryLogger.shared.log("面积检查: \(String(format: "%.0f", area))m² ✓", type: .info)

        // 全部通过
        TerritoryLogger.shared.log("领地验证通过！面积: \(String(format: "%.0f", area))m²", type: .success)
        return (true, nil)
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {

    /// 授权状态变化
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let status = manager.authorizationStatus
            self.authorizationStatus = status

            print("📍 [定位] 授权状态变化: \(self.authorizationStatusString)")

            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                print("✅ [定位] 已获得授权，开始定位")
                self.locationError = nil
                self.startUpdatingLocation()

            case .denied:
                print("❌ [定位] 用户拒绝了定位权限")
                self.locationError = "定位权限被拒绝，请在设置中开启"
                self.stopUpdatingLocation()

            case .restricted:
                print("⚠️ [定位] 定位权限受限")
                self.locationError = "定位功能受限"
                self.stopUpdatingLocation()

            case .notDetermined:
                print("📍 [定位] 等待用户授权...")

            @unknown default:
                break
            }
        }
    }

    /// 位置更新成功
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        Task { @MainActor in
            // 更新用户位置坐标
            self.userLocation = location.coordinate
            self.locationError = nil

            // ⭐ 关键：更新 currentLocation，Timer 需要用这个
            self.currentLocation = location

            print("📍 [定位] 位置更新: (\(location.coordinate.latitude), \(location.coordinate.longitude))")
        }
    }

    /// 位置更新失败
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            print("❌ [定位] 定位失败: \(error.localizedDescription)")

            // 判断错误类型
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    self.locationError = "定位权限被拒绝"
                case .locationUnknown:
                    self.locationError = "无法获取位置，请稍后重试"
                case .network:
                    self.locationError = "网络错误，请检查网络连接"
                default:
                    self.locationError = "定位失败: \(error.localizedDescription)"
                }
            } else {
                self.locationError = "定位失败: \(error.localizedDescription)"
            }
        }
    }
}
