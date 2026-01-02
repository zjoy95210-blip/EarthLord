//
//  LocationManager.swift
//  EarthLord
//
//  GPS 定位管理器 - 处理用户位置获取和权限管理
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

    // MARK: - Private Properties

    /// CoreLocation 管理器
    private let locationManager: CLLocationManager

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

    // MARK: - Initialization

    override private init() {
        self.locationManager = CLLocationManager()
        self.authorizationStatus = locationManager.authorizationStatus

        super.init()

        // 配置定位管理器
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10  // 移动10米才更新

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

    // MARK: - Private Methods

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
            self.userLocation = location.coordinate
            self.locationError = nil

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
