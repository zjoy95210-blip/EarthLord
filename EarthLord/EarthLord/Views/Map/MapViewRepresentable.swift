//
//  MapViewRepresentable.swift
//  EarthLord
//
//  MKMapView 的 SwiftUI 包装器 - 显示末世风格地图和轨迹
//

import SwiftUI
import MapKit

// MARK: - MapViewRepresentable
struct MapViewRepresentable: UIViewRepresentable {

    /// 用户位置（双向绑定）
    @Binding var userLocation: CLLocationCoordinate2D?

    /// 是否已完成首次定位
    @Binding var hasLocatedUser: Bool

    /// 地图缩放级别（米）
    var zoomLevel: Double = 1000

    // MARK: - 轨迹相关属性

    /// 追踪路径坐标数组（WGS-84 原始坐标）
    @Binding var trackingPath: [CLLocationCoordinate2D]

    /// 路径更新版本号（用于检测更新）
    var pathUpdateVersion: Int

    /// 是否正在追踪
    var isTracking: Bool

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()

        // 配置地图类型：卫星图+道路标签（末世风格）
        mapView.mapType = .hybrid

        // 隐藏 POI 标签（商店、餐厅等）
        mapView.pointOfInterestFilter = .excludingAll

        // 隐藏 3D 建筑
        mapView.showsBuildings = false

        // 显示用户位置蓝点（关键！）
        mapView.showsUserLocation = true

        // 允许缩放和拖动
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = true
        mapView.isPitchEnabled = false  // 禁用倾斜（保持2D视角）

        // 显示指南针
        mapView.showsCompass = true

        // 设置代理（关键！否则 didUpdate userLocation 不会被调用）
        mapView.delegate = context.coordinator

        // 应用末世滤镜效果
        applyApocalypseFilter(to: mapView)

        // 监听重新居中通知
        context.coordinator.setupNotificationObserver(for: mapView)

        print("🗺️ [地图] MKMapView 创建完成")

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 检测路径版本变化，更新轨迹
        if context.coordinator.lastPathVersion != pathUpdateVersion {
            context.coordinator.lastPathVersion = pathUpdateVersion
            context.coordinator.updateTrackingPath(on: mapView, coordinates: trackingPath)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - 末世滤镜效果

    private func applyApocalypseFilter(to mapView: MKMapView) {
        // 创建色调控制滤镜：降低饱和度和亮度
        guard let colorControls = CIFilter(name: "CIColorControls") else {
            print("⚠️ [地图] 无法创建 CIColorControls 滤镜")
            return
        }
        colorControls.setValue(-0.15, forKey: kCIInputBrightnessKey)  // 稍微变暗
        colorControls.setValue(0.5, forKey: kCIInputSaturationKey)   // 降低饱和度

        // 创建棕褐色调滤镜：废土的泛黄效果
        guard let sepiaFilter = CIFilter(name: "CISepiaTone") else {
            print("⚠️ [地图] 无法创建 CISepiaTone 滤镜")
            return
        }
        sepiaFilter.setValue(0.65, forKey: kCIInputIntensityKey)

        // 应用滤镜到地图图层
        mapView.layer.filters = [colorControls, sepiaFilter]

        print("🎨 [地图] 末世滤镜效果已应用")
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {

        var parent: MapViewRepresentable

        /// 首次居中标志（防止重复居中，不影响用户手动拖动）
        private var hasInitialCentered = false

        /// 地图视图引用
        private weak var mapView: MKMapView?

        /// 轨迹 Overlay 引用（用于更新时移除旧的）
        private var currentPathOverlay: MKPolyline?

        /// 上次路径版本号（用于检测更新）
        var lastPathVersion: Int = 0

        init(_ parent: MapViewRepresentable) {
            self.parent = parent
            super.init()
        }

        /// 设置通知观察者
        func setupNotificationObserver(for mapView: MKMapView) {
            self.mapView = mapView

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleRecenterNotification(_:)),
                name: NSNotification.Name("RecenterMapToUser"),
                object: nil
            )
        }

        /// 处理重新居中通知
        @objc private func handleRecenterNotification(_ notification: Notification) {
            guard let mapView = mapView,
                  let coordinate = notification.object as? CLLocationCoordinate2D else {
                return
            }

            let region = MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: parent.zoomLevel,
                longitudinalMeters: parent.zoomLevel
            )

            mapView.setRegion(region, animated: true)
            print("📍 [地图] 已重新居中到用户位置")
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        // MARK: - 轨迹更新

        /// 更新追踪路径
        func updateTrackingPath(on mapView: MKMapView, coordinates: [CLLocationCoordinate2D]) {
            // 移除旧的轨迹
            if let oldOverlay = currentPathOverlay {
                mapView.removeOverlay(oldOverlay)
                currentPathOverlay = nil
            }

            // 如果没有坐标点，直接返回
            guard coordinates.count >= 2 else {
                print("📍 [轨迹] 坐标点不足，跳过绘制")
                return
            }

            // ⭐ 关键：转换坐标（WGS-84 → GCJ-02）
            let gcj02Coordinates = CoordinateConverter.wgs84ToGcj02(coordinates)

            // 创建 Polyline
            let polyline = MKPolyline(coordinates: gcj02Coordinates, count: gcj02Coordinates.count)

            // 添加到地图
            mapView.addOverlay(polyline)
            currentPathOverlay = polyline

            print("🛤️ [轨迹] 已更新轨迹，点数: \(coordinates.count)")
        }

        // MARK: - MKMapViewDelegate

        /// ⭐ 关键方法：用户位置更新时调用
        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            // 获取位置
            guard let location = userLocation.location else {
                print("⚠️ [地图] 用户位置为空")
                return
            }

            // 更新绑定的位置
            DispatchQueue.main.async {
                self.parent.userLocation = location.coordinate
            }

            print("📍 [地图] 用户位置更新: (\(location.coordinate.latitude), \(location.coordinate.longitude))")

            // 首次获得位置时，自动居中地图
            guard !hasInitialCentered else { return }

            // 创建居中区域（约1公里范围）
            let region = MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: parent.zoomLevel,
                longitudinalMeters: parent.zoomLevel
            )

            // 平滑居中地图
            mapView.setRegion(region, animated: true)

            // 标记已完成首次居中
            hasInitialCentered = true

            // 更新外部状态
            DispatchQueue.main.async {
                self.parent.hasLocatedUser = true
            }

            print("✅ [地图] 首次定位完成，地图已居中")
        }

        /// ⭐ 关键方法：渲染 Overlay（轨迹线）
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            // 处理 Polyline（轨迹线）
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.cyan  // 青色
                renderer.lineWidth = 5               // 线宽 5pt
                renderer.lineCap = .round            // 圆头
                renderer.lineJoin = .round           // 圆角连接
                renderer.alpha = 0.9                 // 透明度

                print("🎨 [轨迹] 轨迹渲染器已创建")
                return renderer
            }

            // 默认渲染器
            return MKOverlayRenderer(overlay: overlay)
        }

        /// 地图区域变化
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // 可以在这里处理地图拖动后的逻辑
        }

        /// 地图加载完成
        func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
            print("✅ [地图] 地图加载完成")
        }

        /// 地图加载失败
        func mapViewDidFailLoadingMap(_ mapView: MKMapView, withError error: Error) {
            print("❌ [地图] 地图加载失败: \(error.localizedDescription)")
        }

        /// 用户位置跟踪模式变化
        func mapView(_ mapView: MKMapView, didChange mode: MKUserTrackingMode, animated: Bool) {
            print("📍 [地图] 跟踪模式变化: \(mode.rawValue)")
        }

        // MARK: - Public Methods

        /// 重新居中到用户位置
        func recenterToUser(mapView: MKMapView) {
            guard let location = mapView.userLocation.location else {
                print("⚠️ [地图] 无法获取用户位置")
                return
            }

            let region = MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: parent.zoomLevel,
                longitudinalMeters: parent.zoomLevel
            )

            mapView.setRegion(region, animated: true)
            print("📍 [地图] 已重新居中到用户位置")
        }
    }
}

// MARK: - Preview

#Preview {
    MapViewRepresentable(
        userLocation: .constant(nil),
        hasLocatedUser: .constant(false),
        zoomLevel: 1000,
        trackingPath: .constant([]),
        pathUpdateVersion: 0,
        isTracking: false
    )
}
