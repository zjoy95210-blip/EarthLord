//
//  MapTabView.swift
//  EarthLord
//
//  地图页面 - 显示末世风格地图、用户位置和圈地功能
//

import SwiftUI
import MapKit

struct MapTabView: View {

    // MARK: - Properties

    /// 定位管理器
    @StateObject private var locationManager = LocationManager.shared

    /// 用户位置坐标
    @State private var userLocation: CLLocationCoordinate2D?

    /// 是否已完成首次定位
    @State private var hasLocatedUser = false

    /// 地图视图引用（用于重新居中）
    @State private var mapView: MKMapView?

    // MARK: - Body

    var body: some View {
        ZStack {
            // 地图视图（添加轨迹相关参数）
            MapViewRepresentable(
                userLocation: $userLocation,
                hasLocatedUser: $hasLocatedUser,
                zoomLevel: 1000,
                trackingPath: $locationManager.pathCoordinates,
                pathUpdateVersion: locationManager.pathUpdateVersion,
                isTracking: locationManager.isTracking
            )
            .ignoresSafeArea()

            // 顶部渐变遮罩（让状态栏更清晰）
            VStack {
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.6),
                        Color.black.opacity(0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 100)

                Spacer()
            }
            .ignoresSafeArea()

            // UI 叠加层
            VStack {
                // 顶部信息栏
                topInfoBar

                Spacer()

                // 底部控制栏
                bottomControlBar
            }
            .padding()

            // 权限拒绝提示
            if locationManager.isDenied {
                permissionDeniedOverlay
            }
        }
        .onAppear {
            setupLocation()
        }
    }

    // MARK: - 顶部信息栏

    private var topInfoBar: some View {
        HStack {
            // 坐标显示
            if let location = userLocation {
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .foregroundColor(ApocalypseTheme.primary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("当前坐标")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        Text(String(format: "%.4f, %.4f", location.latitude, location.longitude))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(ApocalypseTheme.cardBackground.opacity(0.9))
                .cornerRadius(8)
            } else if locationManager.isAuthorized {
                // 定位中
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                        .scaleEffect(0.8)

                    Text("正在定位...")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(ApocalypseTheme.cardBackground.opacity(0.9))
                .cornerRadius(8)
            }

            Spacer()

            // 地图类型指示
            HStack(spacing: 4) {
                Image(systemName: "globe.asia.australia.fill")
                    .foregroundColor(ApocalypseTheme.primary)

                Text("卫星图")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(ApocalypseTheme.cardBackground.opacity(0.9))
            .cornerRadius(8)
        }
        .padding(.top, 50)  // 避开状态栏
    }

    // MARK: - 底部控制栏

    private var bottomControlBar: some View {
        HStack(alignment: .bottom) {
            // 圈地按钮
            trackingButton

            Spacer()

            // 定位按钮
            Button {
                recenterToUser()
            } label: {
                ZStack {
                    Circle()
                        .fill(ApocalypseTheme.cardBackground)
                        .frame(width: 50, height: 50)

                    Image(systemName: hasLocatedUser ? "location.fill" : "location")
                        .font(.system(size: 20))
                        .foregroundColor(hasLocatedUser ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)
                }
            }
            .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
        }
        .padding(.bottom, 20)
    }

    // MARK: - 圈地按钮

    private var trackingButton: some View {
        Button {
            toggleTracking()
        } label: {
            HStack(spacing: 8) {
                // 图标
                Image(systemName: locationManager.isTracking ? "stop.fill" : "flag.fill")
                    .font(.system(size: 16, weight: .semibold))

                // 文字
                if locationManager.isTracking {
                    Text("停止圈地")
                        .font(.system(size: 14, weight: .semibold))

                    // 显示当前点数
                    Text("(\(locationManager.pathPointCount))")
                        .font(.system(size: 12, weight: .medium))
                        .opacity(0.8)
                } else {
                    Text("开始圈地")
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(locationManager.isTracking ? Color.red : ApocalypseTheme.primary)
            )
            .shadow(color: (locationManager.isTracking ? Color.red : ApocalypseTheme.primary).opacity(0.4), radius: 8, x: 0, y: 4)
        }
        .disabled(!locationManager.isAuthorized)
        .opacity(locationManager.isAuthorized ? 1 : 0.5)
        .animation(.easeInOut(duration: 0.2), value: locationManager.isTracking)
    }

    // MARK: - 权限拒绝覆盖层

    private var permissionDeniedOverlay: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            // 提示卡片
            VStack(spacing: 20) {
                // 图标
                Image(systemName: "location.slash.fill")
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.warning)

                // 标题
                Text("定位权限已关闭")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                // 说明
                Text("《地球新主》需要获取您的位置来显示您在末日世界中的坐标，帮助您探索和圈定领地。")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // 按钮
                Button {
                    locationManager.openSettings()
                } label: {
                    HStack {
                        Image(systemName: "gear")
                        Text("前往设置")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 40)
            }
            .padding(30)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(20)
            .padding(30)
        }
    }

    // MARK: - Methods

    /// 设置定位
    private func setupLocation() {
        print("🗺️ [地图页] 初始化定位...")

        // 检查授权状态
        if locationManager.isNotDetermined {
            // 首次请求权限
            print("📍 [地图页] 首次请求定位权限")
            locationManager.requestPermission()
        } else if locationManager.isAuthorized {
            // 已授权，开始定位
            print("📍 [地图页] 已授权，开始定位")
            locationManager.startUpdatingLocation()
        } else if locationManager.isDenied {
            print("❌ [地图页] 定位权限被拒绝")
        }
    }

    /// 重新居中到用户位置
    private func recenterToUser() {
        guard let location = userLocation else {
            print("⚠️ [地图页] 无法居中：用户位置未知")
            // 如果没有位置，尝试重新请求
            if locationManager.isAuthorized {
                locationManager.requestLocation()
            }
            return
        }

        // 通过通知中心发送居中请求
        NotificationCenter.default.post(
            name: NSNotification.Name("RecenterMapToUser"),
            object: location
        )

        print("📍 [地图页] 请求重新居中到用户位置")
    }

    /// 切换圈地追踪状态
    private func toggleTracking() {
        if locationManager.isTracking {
            // 停止追踪
            locationManager.stopPathTracking()
            print("🛑 [地图页] 停止圈地")
        } else {
            // 开始追踪
            locationManager.startPathTracking()
            print("🚶 [地图页] 开始圈地")
        }
    }
}

// MARK: - Preview

#Preview {
    MapTabView()
}
