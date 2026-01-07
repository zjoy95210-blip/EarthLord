//
//  MapTabView.swift
//  EarthLord
//
//  地图页面 - 显示末世风格地图、用户位置、圈地功能和速度警告
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

    /// 是否显示验证结果横幅
    @State private var showValidationBanner: Bool = false

    /// 是否正在上传领地
    @State private var isUploading: Bool = false

    /// 上传结果提示
    @State private var uploadResultMessage: String?

    /// 是否显示上传结果
    @State private var showUploadResult: Bool = false

    /// 圈地开始时间（用于记录）
    @State private var trackingStartTime: Date?

    /// 领地管理器
    private let territoryManager = TerritoryManager.shared

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
                isTracking: locationManager.isTracking,
                isPathClosed: locationManager.isPathClosed
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
            VStack(spacing: 0) {
                // 速度警告横幅
                if locationManager.speedWarning != nil {
                    speedWarningBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // 顶部信息栏
                topInfoBar

                Spacer()

                // 验证结果横幅（根据验证结果显示成功或失败）
                if showValidationBanner {
                    validationResultBanner
                        .transition(.scale.combined(with: .opacity))
                }

                // 上传结果提示
                if showUploadResult, let message = uploadResultMessage {
                    uploadResultBanner(message: message)
                        .transition(.scale.combined(with: .opacity))
                }

                // 确认登记按钮（验证通过时显示）
                if locationManager.territoryValidationPassed && !isUploading {
                    confirmUploadButton
                        .transition(.scale.combined(with: .opacity))
                }

                // 底部控制栏
                bottomControlBar
            }
            .padding()
            .animation(.easeInOut(duration: 0.3), value: locationManager.speedWarning != nil)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: showValidationBanner)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: locationManager.territoryValidationPassed)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: showUploadResult)

            // 权限拒绝提示
            if locationManager.isDenied {
                permissionDeniedOverlay
            }
        }
        .onAppear {
            setupLocation()
        }
        // 监听闭环状态，闭环后根据验证结果显示横幅
        .onReceive(locationManager.$isPathClosed) { isClosed in
            if isClosed {
                // 闭环后延迟一点点，等待验证结果
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        showValidationBanner = true
                    }
                    // 3 秒后自动隐藏
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {
                            showValidationBanner = false
                        }
                    }
                }
            }
        }
    }

    // MARK: - 速度警告横幅

    private var speedWarningBanner: some View {
        HStack(spacing: 10) {
            // 图标
            Image(systemName: locationManager.isTracking ? "exclamationmark.triangle.fill" : "xmark.octagon.fill")
                .font(.system(size: 18, weight: .semibold))

            // 警告文字
            Text(locationManager.speedWarning ?? "")
                .font(.system(size: 14, weight: .medium))

            Spacer()

            // 关闭按钮
            Button {
                locationManager.clearSpeedWarning()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .padding(6)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Circle())
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(locationManager.isTracking ? Color.orange : Color.red)
        )
        .shadow(color: (locationManager.isTracking ? Color.orange : Color.red).opacity(0.4), radius: 8, x: 0, y: 4)
        .padding(.top, 50)
    }

    // MARK: - 验证结果横幅

    /// 验证结果横幅（根据验证结果显示成功或失败）
    private var validationResultBanner: some View {
        HStack(spacing: 8) {
            // 图标（成功/失败不同）
            Image(systemName: locationManager.territoryValidationPassed
                  ? "checkmark.circle.fill"
                  : "xmark.circle.fill")
                .font(.body)

            // 文字（成功显示面积，失败显示错误信息）
            if locationManager.territoryValidationPassed {
                Text("圈地成功！领地面积: \(String(format: "%.0f", locationManager.calculatedArea))m²")
                    .font(.subheadline)
                    .fontWeight(.medium)
            } else {
                Text(locationManager.territoryValidationError ?? "验证失败")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(locationManager.territoryValidationPassed ? Color.green : Color.red)
        )
        .shadow(color: (locationManager.territoryValidationPassed ? Color.green : Color.red).opacity(0.4),
                radius: 8, x: 0, y: 4)
        .padding(.bottom, 10)
    }

    // MARK: - 确认登记按钮

    /// 确认登记领地按钮
    private var confirmUploadButton: some View {
        Button {
            Task {
                await uploadCurrentTerritory()
            }
        } label: {
            HStack(spacing: 8) {
                if isUploading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 16, weight: .semibold))
                }

                Text(isUploading ? "正在登记..." : "确认登记领地")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.green)
            )
            .shadow(color: Color.green.opacity(0.4), radius: 8, x: 0, y: 4)
        }
        .disabled(isUploading)
        .padding(.bottom, 10)
    }

    // MARK: - 上传结果横幅

    /// 上传结果横幅
    private func uploadResultBanner(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: message.contains("成功") ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.body)

            Text(message)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(message.contains("成功") ? Color.green : Color.red)
        )
        .shadow(color: (message.contains("成功") ? Color.green : Color.red).opacity(0.4),
                radius: 8, x: 0, y: 4)
        .padding(.bottom, 10)
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

            // 速度显示（追踪时）
            if locationManager.isTracking && locationManager.currentSpeed > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "speedometer")
                        .foregroundColor(speedColor)

                    Text(String(format: "%.1f km/h", locationManager.currentSpeed))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(speedColor)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(ApocalypseTheme.cardBackground.opacity(0.9))
                .cornerRadius(8)
            }

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
        .padding(.top, locationManager.speedWarning != nil ? 10 : 50)
    }

    /// 速度颜色（根据速度值变化）
    private var speedColor: Color {
        if locationManager.currentSpeed > 30 {
            return .red
        } else if locationManager.currentSpeed > 15 {
            return .orange
        } else {
            return ApocalypseTheme.primary
        }
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
                Image(systemName: buttonIcon)
                    .font(.system(size: 16, weight: .semibold))

                // 文字
                if locationManager.isPathClosed {
                    Text("重新圈地")
                        .font(.system(size: 14, weight: .semibold))
                } else if locationManager.isTracking {
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
                    .fill(buttonColor)
            )
            .shadow(color: buttonColor.opacity(0.4), radius: 8, x: 0, y: 4)
        }
        .disabled(!locationManager.isAuthorized)
        .opacity(locationManager.isAuthorized ? 1 : 0.5)
        .animation(.easeInOut(duration: 0.2), value: locationManager.isTracking)
        .animation(.easeInOut(duration: 0.2), value: locationManager.isPathClosed)
    }

    /// 按钮图标
    private var buttonIcon: String {
        if locationManager.isPathClosed {
            return "arrow.counterclockwise"
        } else if locationManager.isTracking {
            return "stop.fill"
        } else {
            return "flag.fill"
        }
    }

    /// 按钮颜色
    private var buttonColor: Color {
        if locationManager.isPathClosed {
            return .green
        } else if locationManager.isTracking {
            return .red
        } else {
            return ApocalypseTheme.primary
        }
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
        if locationManager.isPathClosed {
            // 已闭合，重新开始
            resetUploadState()
            locationManager.clearPath()
            locationManager.startPathTracking()
            trackingStartTime = Date()  // 记录开始时间
            print("🔄 [地图页] 重新开始圈地")
        } else if locationManager.isTracking {
            // 停止追踪
            locationManager.stopPathTracking()
            print("🛑 [地图页] 停止圈地")
        } else {
            // 开始追踪
            resetUploadState()
            locationManager.clearPath()  // 确保清除之前的路径
            locationManager.startPathTracking()
            trackingStartTime = Date()  // 记录开始时间
            print("🚶 [地图页] 开始圈地，开始时间: \(trackingStartTime!)")
        }
    }

    // MARK: - 上传领地

    /// 上传当前领地到服务器
    private func uploadCurrentTerritory() async {
        // 验证是否通过
        guard locationManager.territoryValidationPassed else {
            showUploadError("领地验证未通过，无法上传")
            return
        }

        // 获取坐标
        let coordinates = locationManager.pathCoordinates
        guard coordinates.count >= 3 else {
            showUploadError("坐标点不足，无法上传")
            return
        }

        // 开始上传
        isUploading = true
        TerritoryLogger.shared.log("开始上传领地...", type: .info)
        print("🏴 [地图页] 开始上传领地，坐标点数: \(coordinates.count)")

        do {
            try await territoryManager.uploadTerritory(
                coordinates: coordinates,
                area: locationManager.calculatedArea,
                startTime: trackingStartTime ?? Date()
            )

            // 上传成功
            isUploading = false
            showUploadSuccess("领地登记成功！")
            TerritoryLogger.shared.log("领地登记成功！", type: .success)
            print("✅ [地图页] 领地上传成功")

            // 3秒后清除路径和状态
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.resetAfterUpload()
            }

        } catch {
            // 上传失败
            isUploading = false
            let errorMessage = "上传失败: \(error.localizedDescription)"
            showUploadError(errorMessage)
            TerritoryLogger.shared.log(errorMessage, type: .error)
            print("❌ [地图页] \(errorMessage)")
        }
    }

    /// 显示上传成功提示
    private func showUploadSuccess(_ message: String) {
        uploadResultMessage = message
        withAnimation {
            showUploadResult = true
        }

        // 5秒后隐藏
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            withAnimation {
                showUploadResult = false
            }
        }
    }

    /// 显示上传错误提示
    private func showUploadError(_ message: String) {
        uploadResultMessage = message
        withAnimation {
            showUploadResult = true
        }

        // 5秒后隐藏
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            withAnimation {
                showUploadResult = false
            }
        }
    }

    /// 重置上传相关状态
    private func resetUploadState() {
        isUploading = false
        uploadResultMessage = nil
        showUploadResult = false
        showValidationBanner = false
    }

    /// 上传成功后重置所有状态
    private func resetAfterUpload() {
        locationManager.clearPath()
        resetUploadState()
        trackingStartTime = nil
        print("🔄 [地图页] 上传成功后重置状态")
    }
}

// MARK: - Preview

#Preview {
    MapTabView()
}
