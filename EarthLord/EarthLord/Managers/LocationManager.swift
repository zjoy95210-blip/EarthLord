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

    // MARK: - 闭环检测常量

    /// 闭环距离阈值（米）
    private let closureDistanceThreshold: Double = 30.0

    /// 最少路径点数（需要至少这么多点才检测闭环）
    private let minimumPathPoints: Int = 10

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
        if let lastCoordinate = pathCoordinates.last {
            let lastLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
            let distance = location.distance(from: lastLocation)

            // 距离不足，跳过
            if distance < minimumPathDistance {
                return
            }

            print("📍 [路径] 距离上点 \(String(format: "%.1f", distance))米，记录新点")
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

        // 距离小于阈值则闭合成功
        if distance <= closureDistanceThreshold {
            isPathClosed = true

            // 触发 UI 更新
            pathUpdateVersion += 1

            print("✅ [闭环] 闭环检测成功！首尾距离: \(String(format: "%.1f", distance))米")

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
