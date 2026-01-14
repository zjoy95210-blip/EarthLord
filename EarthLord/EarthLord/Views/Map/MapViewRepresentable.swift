//
//  MapViewRepresentable.swift
//  EarthLord
//
//  MKMapView 的 SwiftUI 包装器 - 显示末世风格地图、轨迹和领地
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

    /// 路径是否闭合
    var isPathClosed: Bool

    // MARK: - 领地显示属性

    /// 已加载的领地列表
    var territories: [Territory]

    /// 当前用户 ID（用于区分自己和他人的领地）
    var currentUserId: String?

    // MARK: - POI 显示属性

    /// 附近 POI 列表
    var nearbyPOIs: [ScavengePOI]

    /// POI 更新版本号
    var poiUpdateVersion: Int

    /// POI 点击回调
    var onPOITapped: ((ScavengePOI) -> Void)?

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
        // 更新 Coordinator 中的闭合状态
        context.coordinator.isPathClosed = isPathClosed

        // 更新 POI 点击回调
        context.coordinator.onPOITapped = onPOITapped

        // 检测路径版本变化，更新轨迹
        if context.coordinator.lastPathVersion != pathUpdateVersion {
            context.coordinator.lastPathVersion = pathUpdateVersion
            context.coordinator.updateTrackingPath(on: mapView, coordinates: trackingPath, isPathClosed: isPathClosed)
        }

        // 检测领地列表变化，更新领地显示
        if context.coordinator.lastTerritoryCount != territories.count ||
           context.coordinator.currentUserId != currentUserId {
            context.coordinator.lastTerritoryCount = territories.count
            context.coordinator.currentUserId = currentUserId
            context.coordinator.drawTerritories(on: mapView, territories: territories, currentUserId: currentUserId)
        }

        // 检测 POI 版本变化，更新 POI 标注
        if context.coordinator.lastPOIVersion != poiUpdateVersion {
            context.coordinator.lastPOIVersion = poiUpdateVersion
            context.coordinator.updatePOIAnnotations(on: mapView, pois: nearbyPOIs)
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

        /// 多边形 Overlay 引用（用于更新时移除旧的）
        private var currentPolygonOverlay: MKPolygon?

        /// 上次路径版本号（用于检测更新）
        var lastPathVersion: Int = 0

        /// 路径是否闭合（用于渲染时判断颜色）
        var isPathClosed: Bool = false

        /// 上次领地数量（用于检测更新）
        var lastTerritoryCount: Int = 0

        /// 当前用户 ID
        var currentUserId: String?

        /// 上次 POI 版本号（用于检测更新）
        var lastPOIVersion: Int = 0

        /// POI 标注引用
        private var poiAnnotations: [POIAnnotation] = []

        /// POI 点击回调
        var onPOITapped: ((ScavengePOI) -> Void)?

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
        func updateTrackingPath(on mapView: MKMapView, coordinates: [CLLocationCoordinate2D], isPathClosed: Bool) {
            // 移除旧的轨迹线
            if let oldOverlay = currentPathOverlay {
                mapView.removeOverlay(oldOverlay)
                currentPathOverlay = nil
            }

            // 移除旧的多边形
            if let oldPolygon = currentPolygonOverlay {
                mapView.removeOverlay(oldPolygon)
                currentPolygonOverlay = nil
            }

            // 如果没有坐标点，直接返回
            guard coordinates.count >= 2 else {
                print("📍 [轨迹] 坐标点不足，跳过绘制")
                return
            }

            // ⭐ 关键：转换坐标（WGS-84 → GCJ-02）
            let gcj02Coordinates = CoordinateConverter.wgs84ToGcj02(coordinates)

            // 创建 Polyline（轨迹线）
            let polyline = MKPolyline(coordinates: gcj02Coordinates, count: gcj02Coordinates.count)

            // 添加轨迹线到地图
            mapView.addOverlay(polyline)
            currentPathOverlay = polyline

            print("🛤️ [轨迹] 已更新轨迹，点数: \(coordinates.count)，闭合: \(isPathClosed)")

            // ⭐ 如果路径闭合，添加多边形填充
            if isPathClosed && gcj02Coordinates.count >= 3 {
                let polygon = MKPolygon(coordinates: gcj02Coordinates, count: gcj02Coordinates.count)
                mapView.addOverlay(polygon, level: .aboveRoads)
                currentPolygonOverlay = polygon

                print("🟢 [领地] 已创建领地多边形")
            }
        }

        // MARK: - 领地绘制

        /// 绘制已加载的领地
        func drawTerritories(on mapView: MKMapView, territories: [Territory], currentUserId: String?) {
            // 移除旧的领地多边形（保留路径轨迹）
            let territoryOverlays = mapView.overlays.filter { overlay in
                if let polygon = overlay as? MKPolygon {
                    return polygon.title == "mine" || polygon.title == "others"
                }
                return false
            }
            mapView.removeOverlays(territoryOverlays)

            print("🗺️ [领地] 开始绘制 \(territories.count) 个领地")

            // 绘制每个领地
            for territory in territories {
                // ⚠️ 中国大陆需要坐标转换（WGS-84 → GCJ-02）
                let coords = CoordinateConverter.wgs84ToGcj02(territory.toCoordinates())

                guard coords.count >= 3 else {
                    print("⚠️ [领地] 领地 \(territory.id) 坐标点不足，跳过")
                    continue
                }

                let polygon = MKPolygon(coordinates: coords, count: coords.count)

                // ⚠️ 关键：比较 userId 时必须统一大小写！
                // 数据库存的是小写 UUID，但 iOS 的 uuidString 返回大写
                let isMine = territory.userId.uuidString.lowercased() == currentUserId?.lowercased()
                polygon.title = isMine ? "mine" : "others"

                mapView.addOverlay(polygon, level: .aboveRoads)

                print("🏴 [领地] 绘制领地: \(territory.id)，类型: \(isMine ? "我的" : "他人的")")
            }

            print("✅ [领地] 领地绘制完成")
        }

        // MARK: - POI 标注更新

        /// 更新 POI 标注
        func updatePOIAnnotations(on mapView: MKMapView, pois: [ScavengePOI]) {
            // 移除旧标注
            if !poiAnnotations.isEmpty {
                mapView.removeAnnotations(poiAnnotations)
                poiAnnotations.removeAll()
            }

            // 如果没有 POI，直接返回
            guard !pois.isEmpty else {
                print("📍 [POI] 无 POI 需要显示")
                return
            }

            // 添加新标注
            for poi in pois {
                // ⚠️ MapKit 在中国返回的 POI 坐标已经是 GCJ-02，无需转换
                // 直接使用原始坐标即可正确显示在地图上
                let annotation = POIAnnotation(poi: poi)
                annotation.coordinate = poi.coordinate
                annotation.title = poi.name
                annotation.subtitle = "\(poi.category.displayName) · \(poi.formattedDistance)"

                mapView.addAnnotation(annotation)
                poiAnnotations.append(annotation)
            }

            print("📍 [POI] 已更新 \(pois.count) 个 POI 标注")
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

        /// ⭐ 关键方法：渲染 Overlay（轨迹线和多边形）
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            // 处理 Polyline（轨迹线）
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)

                // ⭐ 根据闭合状态选择颜色
                if isPathClosed {
                    renderer.strokeColor = UIColor.systemGreen  // 闭合：绿色
                } else {
                    renderer.strokeColor = UIColor.systemCyan   // 未闭合：青色
                }

                renderer.lineWidth = 5               // 线宽 5pt
                renderer.lineCap = .round            // 圆头
                renderer.lineJoin = .round           // 圆角连接
                renderer.alpha = 0.9                 // 透明度

                print("🎨 [轨迹] 轨迹渲染器已创建，颜色: \(isPathClosed ? "绿色" : "青色")")
                return renderer
            }

            // 处理 Polygon（领地多边形）
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)

                // 根据 title 区分自己的领地和他人的领地
                if polygon.title == "mine" {
                    // 我的领地：绿色
                    renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.25)
                    renderer.strokeColor = UIColor.systemGreen
                    print("🎨 [领地] 渲染我的领地（绿色）")
                } else if polygon.title == "others" {
                    // 他人的领地：橙色
                    renderer.fillColor = UIColor.systemOrange.withAlphaComponent(0.25)
                    renderer.strokeColor = UIColor.systemOrange
                    print("🎨 [领地] 渲染他人领地（橙色）")
                } else {
                    // 当前正在圈地的多边形（无 title）：绿色
                    renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.25)
                    renderer.strokeColor = UIColor.systemGreen
                    print("🎨 [领地] 渲染当前圈地多边形（绿色）")
                }

                renderer.lineWidth = 2.0
                return renderer
            }

            // 默认渲染器
            return MKOverlayRenderer(overlay: overlay)
        }

        /// 自定义标注视图
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // 用户位置使用系统默认
            if annotation is MKUserLocation { return nil }

            // POI 标注
            if let poiAnnotation = annotation as? POIAnnotation {
                let identifier = "POIAnnotation"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: poiAnnotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true

                    // 添加详情按钮
                    let detailButton = UIButton(type: .detailDisclosure)
                    annotationView?.rightCalloutAccessoryView = detailButton
                } else {
                    annotationView?.annotation = poiAnnotation
                }

                // 根据 POI 类型和状态设置颜色和图标
                let poi = poiAnnotation.poi

                // 已搜刮的 POI 显示灰色
                if poi.status == .depleted {
                    annotationView?.markerTintColor = .systemGray
                    annotationView?.alpha = 0.6
                } else {
                    annotationView?.markerTintColor = UIColor(poi.category.color)
                    annotationView?.alpha = 1.0
                }

                annotationView?.glyphImage = UIImage(systemName: poi.category.iconName)

                return annotationView
            }

            return nil
        }

        /// 标注点击回调
        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
            guard let poiAnnotation = view.annotation as? POIAnnotation else { return }

            // 触发回调
            onPOITapped?(poiAnnotation.poi)
        }

        /// 选中标注
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let poiAnnotation = view.annotation as? POIAnnotation else { return }
            print("📍 [POI] 选中: \(poiAnnotation.poi.name)")
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

// MARK: - POI Annotation

/// POI 标注类
class POIAnnotation: MKPointAnnotation {
    let poi: ScavengePOI

    init(poi: ScavengePOI) {
        self.poi = poi
        super.init()
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
        isTracking: false,
        isPathClosed: false,
        territories: [],
        currentUserId: nil,
        nearbyPOIs: [],
        poiUpdateVersion: 0,
        onPOITapped: nil
    )
}
