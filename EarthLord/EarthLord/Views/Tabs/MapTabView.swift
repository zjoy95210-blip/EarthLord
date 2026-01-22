//
//  MapTabView.swift
//  EarthLord
//
//  地图页面 - 显示末世风格地图、用户位置、圈地功能和速度警告
//

import SwiftUI
import MapKit
import UIKit
import Auth

struct MapTabView: View {

    // MARK: - Properties

    /// 定位管理器
    @StateObject private var locationManager = LocationManager.shared

    /// 认证管理器
    @StateObject private var authManager = AuthManager.shared

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

    /// 已加载的领地列表
    @State private var territories: [Territory] = []

    // MARK: - Day 19: 碰撞检测状态
    @State private var collisionCheckTimer: Timer?
    @State private var collisionWarning: String?
    @State private var showCollisionWarning = false
    @State private var collisionWarningLevel: WarningLevel = .safe

    // MARK: - 探索功能状态
    /// 探索管理器
    @State private var explorationManager = ExplorationManager.shared
    /// 是否显示探索结果 sheet
    @State private var showExplorationResult: Bool = false
    /// 探索结果数据
    @State private var explorationResult: ExplorationResult?
    /// 探索错误信息
    @State private var explorationError: String?

    // MARK: - POI 搜刮状态
    /// 是否显示 POI 搜刮弹窗
    @State private var showScavengePopup: Bool = false
    /// 当前弹窗 POI
    @State private var popupPOI: ScavengePOI?
    /// 搜刮结果（AI 生成物品）
    @State private var scavengeResult: [AIRewardedItem]?
    /// 搜刮结果对应的 POI
    @State private var scavengeResultPOI: ScavengePOI?
    /// 是否正在搜刮
    @State private var isScavenging: Bool = false
    /// 是否显示搜刮结果
    @State private var showScavengeResult: Bool = false

    /// 领地管理器
    private let territoryManager = TerritoryManager.shared

    // MARK: - Body

    var body: some View {
        ZStack {
            // 地图视图（添加轨迹相关参数和领地显示）
            MapViewRepresentable(
                userLocation: $userLocation,
                hasLocatedUser: $hasLocatedUser,
                zoomLevel: 1000,
                trackingPath: $locationManager.pathCoordinates,
                pathUpdateVersion: locationManager.pathUpdateVersion,
                isTracking: locationManager.isTracking,
                isPathClosed: locationManager.isPathClosed,
                territories: territories,
                currentUserId: authManager.currentUser?.id.uuidString,
                nearbyPOIs: explorationManager.nearbyPOIs,
                poiUpdateVersion: explorationManager.poiUpdateVersion,
                onPOITapped: { poi in
                    // POI 被点击时显示弹窗
                    if poi.canScavenge {
                        popupPOI = poi
                        showScavengePopup = true
                    }
                }
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

                // 探索超速警告
                if explorationManager.isExploring && explorationManager.isOverSpeed {
                    explorationOverSpeedWarning
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // 探索状态条
                if explorationManager.isExploring {
                    explorationStatusBar
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

            // Day 19: 碰撞警告横幅（分级颜色）
            if showCollisionWarning, let warning = collisionWarning {
                collisionWarningBanner(message: warning, level: collisionWarningLevel)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showCollisionWarning)
        .sheet(isPresented: $showExplorationResult) {
            if let result = explorationResult {
                ExplorationResultView(explorationResult: result)
            } else if let error = explorationError {
                ExplorationResultView(errorMessage: error, onRetry: {
                    showExplorationResult = false
                    Task {
                        await startExplorationAsync()
                    }
                })
            }
        }
        .animation(.easeInOut(duration: 0.3), value: explorationManager.isExploring)
        .animation(.easeInOut(duration: 0.3), value: explorationManager.isOverSpeed)
        // POI 搜刮弹窗
        .sheet(isPresented: $showScavengePopup) {
            if let poi = popupPOI {
                POIProximityPopup(
                    poi: poi,
                    isScavenging: $isScavenging,
                    onScavenge: {
                        await performScavenge(poi: poi)
                    },
                    onDismiss: {
                        showScavengePopup = false
                    }
                )
                .presentationDetents([.height(280)])
                .presentationDragIndicator(.visible)
            }
        }
        // 搜刮结果弹窗
        .sheet(isPresented: $showScavengeResult) {
            if let aiRewards = scavengeResult, let poi = scavengeResultPOI {
                ScavengeResultView(aiRewards: aiRewards, poi: poi)
            }
        }
        // 监听 ExplorationManager 的弹窗状态
        .onChange(of: explorationManager.showScavengePopup) { _, show in
            if show {
                popupPOI = explorationManager.popupPOI
                showScavengePopup = true
                explorationManager.showScavengePopup = false
            }
        }
        // 监听探索开始，搜索附近 POI
        .onChange(of: explorationManager.isExploring) { _, isExploring in
            if isExploring {
                // 探索开始，搜索附近 POI
                Task {
                    await explorationManager.searchNearbyPOIs()
                }
            }
        }
        // 监听探索状态，处理超速停止
        .onChange(of: explorationManager.state) { oldValue, newValue in
            if case .failed(let message) = newValue {
                // 探索失败（包括超速停止）
                print("🔔 [地图页] 探索失败状态: \(message)")
                explorationError = message
                explorationResult = nil
                showExplorationResult = true
            }
        }
        .onAppear {
            setupLocation()
            // 加载已有领地
            Task {
                await loadTerritories()
            }
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
        HStack(alignment: .bottom, spacing: 12) {
            // 左侧：圈地按钮
            trackingButton

            Spacer()

            // 中间：定位按钮
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

            Spacer()

            // 右侧：探索按钮
            exploreButton
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

    // MARK: - 探索超速警告

    private var explorationOverSpeedWarning: some View {
        HStack(spacing: 10) {
            // 警告图标
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18, weight: .semibold))

            // 警告文字
            VStack(alignment: .leading, spacing: 2) {
                Text("速度过快！")
                    .font(.system(size: 14, weight: .bold))

                HStack(spacing: 4) {
                    Text("请减速至20km/h以下")
                        .font(.system(size: 12))

                    // 倒计时
                    if explorationManager.overSpeedRemainingSeconds > 0 {
                        Text("(\(explorationManager.overSpeedRemainingSeconds)秒后停止)")
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
            }

            Spacer()

            // 当前速度显示
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.0f", explorationManager.currentSpeed))
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                Text("km/h")
                    .font(.system(size: 10))
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red)
        )
        .shadow(color: Color.red.opacity(0.5), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
        .padding(.top, 50)
    }

    // MARK: - 探索状态条

    private var explorationStatusBar: some View {
        let statusBarColor = explorationManager.isOverSpeed ? Color.orange : Color.green
        let tierColor = Color(hex: explorationManager.currentRewardTier.colorHex)

        return VStack(spacing: 8) {
            // 第一行：距离、时长、速度、结束按钮
            HStack(spacing: 10) {
                // 距离
                HStack(spacing: 4) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 12))
                    Text(formatDistance(explorationManager.totalDistance))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                }

                // 分隔线
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 1, height: 14)

                // 时长
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 12))
                    Text(formatDuration(explorationManager.duration))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                }

                // 分隔线
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 1, height: 14)

                // 速度显示
                HStack(spacing: 2) {
                    Image(systemName: "speedometer")
                        .font(.system(size: 10))
                    Text(String(format: "%.0f", explorationManager.currentSpeed))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                }
                .foregroundColor(explorationManager.isOverSpeed ? .yellow : .white)

                Spacer()

                // 结束按钮
                Button {
                    Task {
                        await stopExplorationAsync()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 10))
                        Text("结束")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.red.opacity(0.8))
                    )
                }
            }

            // 分隔线
            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(height: 1)

            // 第二行：奖励等级和距离下一等级
            HStack(spacing: 8) {
                // 当前奖励等级
                HStack(spacing: 4) {
                    Image(systemName: explorationManager.currentRewardTier.iconName)
                        .font(.system(size: 12))
                        .foregroundColor(tierColor)
                    Text(explorationManager.currentRewardTier.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(tierColor)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                )

                // 距离下一等级
                if let nextTier = explorationManager.nextTierName {
                    HStack(spacing: 4) {
                        Text("距\(nextTier)还差")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.8))
                        Text(formatDistance(explorationManager.distanceToNextTier))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(.yellow)
                    }
                } else {
                    // 已是最高等级
                    Text("已达最高等级！")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.yellow)
                }

                Spacer()
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(statusBarColor.opacity(0.9))
        )
        .shadow(color: statusBarColor.opacity(0.4), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
        .padding(.top, explorationManager.isOverSpeed ? 10 : 50)
        .animation(.easeInOut(duration: 0.3), value: explorationManager.isOverSpeed)
        .animation(.easeInOut(duration: 0.3), value: explorationManager.currentRewardTier)
    }

    /// 格式化距离
    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.2f km", meters / 1000)
        } else {
            return String(format: "%.0f m", meters)
        }
    }

    /// 格式化时长
    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }

    // MARK: - 探索按钮

    private var exploreButton: some View {
        Button {
            Task {
                if explorationManager.isExploring {
                    await stopExplorationAsync()
                } else {
                    await startExplorationAsync()
                }
            }
        } label: {
            HStack(spacing: 8) {
                if explorationManager.state == .finishing {
                    // 结算中
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                    Text("结算中...")
                        .font(.system(size: 14, weight: .semibold))
                } else if explorationManager.isExploring {
                    // 探索中 - 显示停止按钮
                    Image(systemName: "stop.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("结束")
                        .font(.system(size: 14, weight: .semibold))
                } else {
                    // 空闲状态
                    Image(systemName: "binoculars.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("探索")
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(explorationManager.isExploring ? Color.red : ApocalypseTheme.primary)
            )
            .shadow(color: (explorationManager.isExploring ? Color.red : ApocalypseTheme.primary).opacity(0.4),
                    radius: 8, x: 0, y: 4)
        }
        .disabled(explorationManager.state == .finishing)
        .animation(.easeInOut(duration: 0.2), value: explorationManager.isExploring)
    }

    /// 开始探索
    private func startExplorationAsync() async {
        print("🔍 [地图页] 开始探索请求...")
        explorationError = nil
        explorationResult = nil

        // 如果之前是失败状态，先重置
        if case .failed = explorationManager.state {
            print("🔄 [地图页] 重置之前的失败状态")
            explorationManager.reset()
        }

        do {
            try await explorationManager.startExploration()
            print("✅ [地图页] 探索已开始")
        } catch {
            print("❌ [地图页] 开始探索失败: \(error.localizedDescription)")
            explorationError = error.localizedDescription
            showExplorationResult = true
        }
    }

    /// 结束探索
    private func stopExplorationAsync() async {
        print("🛑 [地图页] 结束探索...")

        do {
            let result = try await explorationManager.stopExploration()
            explorationResult = result
            explorationError = nil
            showExplorationResult = true
            print("✅ [地图页] 探索完成，距离: \(result.formattedDistance)")
        } catch {
            print("❌ [地图页] 结束探索失败: \(error.localizedDescription)")
            explorationError = error.localizedDescription
            showExplorationResult = true
        }
    }

    /// 执行 POI 搜刮
    private func performScavenge(poi: ScavengePOI) async {
        print("🔍 [地图页] 开始搜刮 POI: \(poi.name) (危险等级: \(poi.dangerLevel.displayName))")
        isScavenging = true

        do {
            let aiRewards = try await explorationManager.scavengePOI(poi)
            isScavenging = false
            showScavengePopup = false

            // 延迟显示结果，等待弹窗关闭动画
            try? await Task.sleep(nanoseconds: 300_000_000)

            scavengeResult = aiRewards
            scavengeResultPOI = poi
            showScavengeResult = true

            print("✅ [地图页] 搜刮完成，获得 \(aiRewards.count) 个 AI 生成物品")

        } catch {
            isScavenging = false
            print("❌ [地图页] 搜刮失败: \(error.localizedDescription)")
            // 可以在这里添加错误提示
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
                Text("《ZXH希望之地》需要获取您的位置来显示您在末日世界中的坐标，帮助您探索和圈定领地。")
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

    /// 加载所有领地
    private func loadTerritories() async {
        print("🗺️ [地图页] 开始加载领地...")

        do {
            territories = try await territoryManager.loadAllTerritories()
            TerritoryLogger.shared.log("加载了 \(territories.count) 个领地", type: .info)
            print("✅ [地图页] 领地加载完成，共 \(territories.count) 个")
        } catch {
            TerritoryLogger.shared.log("加载领地失败: \(error.localizedDescription)", type: .error)
            print("❌ [地图页] 领地加载失败: \(error.localizedDescription)")
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
            // 已闭合，重新开始 - 使用碰撞检测
            resetUploadState()
            locationManager.clearPath()
            startClaimingWithCollisionCheck()
            print("🔄 [地图页] 重新开始圈地")
        } else if locationManager.isTracking {
            // 停止追踪 - 完全停止碰撞监控
            stopCollisionMonitoring()
            locationManager.stopPathTracking()
            print("🛑 [地图页] 停止圈地")
        } else {
            // 开始追踪 - 使用碰撞检测
            resetUploadState()
            locationManager.clearPath()
            startClaimingWithCollisionCheck()
        }
    }

    // MARK: - Day 19: 碰撞检测方法

    /// Day 19: 带碰撞检测的开始圈地
    private func startClaimingWithCollisionCheck() {
        guard let location = locationManager.userLocation,
              let userId = authManager.currentUser?.id.uuidString else {
            return
        }

        // 检测起始点是否在他人领地内
        let result = territoryManager.checkPointCollision(
            location: location,
            currentUserId: userId
        )

        if result.hasCollision {
            // 起点在他人领地内，显示错误并震动
            collisionWarning = result.message
            collisionWarningLevel = .violation
            showCollisionWarning = true

            // 错误震动
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.error)

            TerritoryLogger.shared.log("起点碰撞：阻止圈地", type: .error)

            // 3秒后隐藏警告
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showCollisionWarning = false
                collisionWarning = nil
                collisionWarningLevel = .safe
            }

            return
        }

        // 起点安全，开始圈地
        TerritoryLogger.shared.log("起始点安全，开始圈地", type: .info)
        trackingStartTime = Date()
        locationManager.startPathTracking()
        startCollisionMonitoring()
        print("🚶 [地图页] 开始圈地，开始时间: \(trackingStartTime!)")
    }

    /// Day 19: 启动碰撞检测监控
    private func startCollisionMonitoring() {
        // 先停止已有定时器
        stopCollisionCheckTimer()

        // 每 10 秒检测一次
        collisionCheckTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [self] _ in
            performCollisionCheck()
        }

        TerritoryLogger.shared.log("碰撞检测定时器已启动", type: .info)
    }

    /// Day 19: 仅停止定时器（不清除警告状态）
    private func stopCollisionCheckTimer() {
        collisionCheckTimer?.invalidate()
        collisionCheckTimer = nil
        TerritoryLogger.shared.log("碰撞检测定时器已停止", type: .info)
    }

    /// Day 19: 完全停止碰撞监控（停止定时器 + 清除警告）
    private func stopCollisionMonitoring() {
        stopCollisionCheckTimer()
        // 清除警告状态
        showCollisionWarning = false
        collisionWarning = nil
        collisionWarningLevel = .safe
    }

    /// Day 19: 执行碰撞检测
    private func performCollisionCheck() {
        guard locationManager.isTracking,
              let userId = authManager.currentUser?.id.uuidString else {
            return
        }

        let path = locationManager.pathCoordinates
        guard path.count >= 2 else { return }

        let result = territoryManager.checkPathCollisionComprehensive(
            path: path,
            currentUserId: userId
        )

        // 根据预警级别处理
        switch result.warningLevel {
        case .safe:
            // 安全，隐藏警告横幅
            showCollisionWarning = false
            collisionWarning = nil
            collisionWarningLevel = .safe

        case .caution:
            // 注意（50-100m）- 黄色横幅 + 轻震 1 次
            collisionWarning = result.message
            collisionWarningLevel = .caution
            showCollisionWarning = true
            triggerHapticFeedback(level: .caution)

        case .warning:
            // 警告（25-50m）- 橙色横幅 + 中震 2 次
            collisionWarning = result.message
            collisionWarningLevel = .warning
            showCollisionWarning = true
            triggerHapticFeedback(level: .warning)

        case .danger:
            // 危险（<25m）- 红色横幅 + 强震 3 次
            collisionWarning = result.message
            collisionWarningLevel = .danger
            showCollisionWarning = true
            triggerHapticFeedback(level: .danger)

        case .violation:
            // 【关键】违规处理 - 必须先显示横幅，再停止！

            // 1. 先设置警告状态（让横幅显示出来）
            collisionWarning = result.message
            collisionWarningLevel = .violation
            showCollisionWarning = true

            // 2. 触发震动
            triggerHapticFeedback(level: .violation)

            // 3. 只停止定时器，不清除警告状态！
            stopCollisionCheckTimer()

            // 4. 停止圈地追踪
            locationManager.stopPathTracking()
            trackingStartTime = nil

            TerritoryLogger.shared.log("碰撞违规，自动停止圈地", type: .error)

            // 5. 5秒后再清除警告横幅
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                showCollisionWarning = false
                collisionWarning = nil
                collisionWarningLevel = .safe
            }
        }
    }

    /// Day 19: 触发震动反馈
    private func triggerHapticFeedback(level: WarningLevel) {
        switch level {
        case .safe:
            // 安全：无震动
            break

        case .caution:
            // 注意：轻震 1 次
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.warning)

        case .warning:
            // 警告：中震 2 次
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                generator.impactOccurred()
            }

        case .danger:
            // 危险：强震 3 次
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.prepare()
            generator.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                generator.impactOccurred()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                generator.impactOccurred()
            }

        case .violation:
            // 违规：错误震动
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.error)
        }
    }

    /// Day 19: 碰撞警告横幅（分级颜色）
    private func collisionWarningBanner(message: String, level: WarningLevel) -> some View {
        // 根据级别确定颜色
        let backgroundColor: Color
        switch level {
        case .safe:
            backgroundColor = .green
        case .caution:
            backgroundColor = .yellow
        case .warning:
            backgroundColor = .orange
        case .danger, .violation:
            backgroundColor = .red
        }

        // 根据级别确定文字颜色（黄色背景用黑字）
        let textColor: Color = (level == .caution) ? .black : .white

        // 根据级别确定图标
        let iconName = (level == .violation) ? "xmark.octagon.fill" : "exclamationmark.triangle.fill"

        return VStack {
            HStack {
                Image(systemName: iconName)
                    .font(.system(size: 18))

                Text(message)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(textColor)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(backgroundColor.opacity(0.95))
            .cornerRadius(25)
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            .padding(.top, 120)

            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
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
            stopCollisionMonitoring()  // Day 19: 上传成功后停止碰撞监控
            showUploadSuccess("领地登记成功！")
            TerritoryLogger.shared.log("领地登记成功！", type: .success)
            print("✅ [地图页] 领地上传成功")

            // 刷新领地列表，显示新上传的领地
            await loadTerritories()

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
