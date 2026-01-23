//
//  TerritoryMapView.swift
//  EarthLord
//
//  领地地图组件（UIKit MKMapView 封装）
//

import SwiftUI
import MapKit

// MARK: - 领地地图视图
struct TerritoryMapView: UIViewRepresentable {

    // MARK: - Properties

    /// 领地多边形坐标
    let polygonCoordinates: [CLLocationCoordinate2D]

    /// 领地内的建筑列表
    let buildings: [PlayerBuilding]

    /// 建筑模板查询闭包
    let getTemplate: (String) -> BuildingTemplate?

    /// 地图中心点（可选，默认使用多边形中心）
    var centerCoordinate: CLLocationCoordinate2D?

    /// 地图缩放级别（span）
    var spanDelta: Double = 0.005

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = false
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.mapType = .standard

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 移除旧的覆盖物和标注
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)

        // 添加领地多边形
        if !polygonCoordinates.isEmpty {
            let polygon = MKPolygon(coordinates: polygonCoordinates, count: polygonCoordinates.count)
            mapView.addOverlay(polygon)

            // 计算中心点
            let center = centerCoordinate ?? calculateCenter(from: polygonCoordinates)

            // 设置地图区域
            let region = MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: spanDelta, longitudeDelta: spanDelta)
            )
            mapView.setRegion(region, animated: false)
        }

        // 添加建筑标注
        for building in buildings {
            if let coordinate = building.coordinate {
                let annotation = BuildingAnnotation(building: building, getTemplate: getTemplate)
                mapView.addAnnotation(annotation)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - Helper Methods

    /// 计算多边形中心点
    private func calculateCenter(from coordinates: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D {
        guard !coordinates.isEmpty else {
            return CLLocationCoordinate2D(latitude: 0, longitude: 0)
        }

        let totalLat = coordinates.reduce(0) { $0 + $1.latitude }
        let totalLon = coordinates.reduce(0) { $0 + $1.longitude }
        let count = Double(coordinates.count)

        return CLLocationCoordinate2D(
            latitude: totalLat / count,
            longitude: totalLon / count
        )
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = UIColor(ApocalypseTheme.primary).withAlphaComponent(0.2)
                renderer.strokeColor = UIColor(ApocalypseTheme.primary)
                renderer.lineWidth = 2
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let buildingAnnotation = annotation as? BuildingAnnotation else {
                return nil
            }

            let identifier = "BuildingAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: buildingAnnotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = buildingAnnotation
            }

            // 根据建筑状态设置颜色
            switch buildingAnnotation.building.status {
            case .constructing:
                annotationView?.markerTintColor = UIColor(ApocalypseTheme.warning)
                annotationView?.glyphImage = UIImage(systemName: "hammer.fill")
            case .upgrading:
                annotationView?.markerTintColor = UIColor(ApocalypseTheme.info)
                annotationView?.glyphImage = UIImage(systemName: "arrow.up.circle.fill")
            case .active:
                if let template = buildingAnnotation.getTemplate?(buildingAnnotation.building.templateId) {
                    annotationView?.markerTintColor = UIColor(Color(hex: template.category.colorHex))
                    annotationView?.glyphImage = UIImage(systemName: template.iconName)
                } else {
                    annotationView?.markerTintColor = UIColor(ApocalypseTheme.success)
                    annotationView?.glyphImage = UIImage(systemName: "building.2.fill")
                }
            }

            return annotationView
        }
    }
}

// MARK: - 建筑标注
class BuildingAnnotation: NSObject, MKAnnotation {

    let building: PlayerBuilding
    let getTemplate: ((String) -> BuildingTemplate?)?

    var coordinate: CLLocationCoordinate2D {
        building.coordinate ?? CLLocationCoordinate2D(latitude: 0, longitude: 0)
    }

    var title: String? {
        if let template = getTemplate?(building.templateId) {
            return template.name
        }
        return "建筑"
    }

    var subtitle: String? {
        "Lv.\(building.level) - \(building.status.displayName)"
    }

    init(building: PlayerBuilding, getTemplate: ((String) -> BuildingTemplate?)?) {
        self.building = building
        self.getTemplate = getTemplate
        super.init()
    }
}

// MARK: - Preview
#Preview {
    let sampleCoordinates = [
        CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737),
        CLLocationCoordinate2D(latitude: 31.2314, longitude: 121.4737),
        CLLocationCoordinate2D(latitude: 31.2314, longitude: 121.4747),
        CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4747)
    ]

    TerritoryMapView(
        polygonCoordinates: sampleCoordinates,
        buildings: [],
        getTemplate: { _ in nil }
    )
    .ignoresSafeArea()
}
