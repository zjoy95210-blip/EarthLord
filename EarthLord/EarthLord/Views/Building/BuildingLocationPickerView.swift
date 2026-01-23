//
//  BuildingLocationPickerView.swift
//  EarthLord
//
//  地图位置选择器（UIKit MKMapView）
//

import SwiftUI
import MapKit

struct BuildingLocationPickerView: View {

    // MARK: - Properties

    /// 领地
    let territory: Territory

    /// 选择位置回调
    let onSelect: (CLLocationCoordinate2D) -> Void

    /// 取消回调
    let onCancel: () -> Void

    /// 领地管理器
    private let territoryManager = TerritoryManager.shared

    /// 选择的位置
    @State private var selectedLocation: CLLocationCoordinate2D?

    /// 位置是否在领地内
    @State private var isLocationValid = false

    /// 错误提示
    @State private var showError = false

    // MARK: - Computed Properties

    /// 领地多边形坐标
    private var polygonCoordinates: [CLLocationCoordinate2D] {
        territory.toCoordinates()
    }

    /// 领地中心点
    private var centerCoordinate: CLLocationCoordinate2D {
        let coords = polygonCoordinates
        guard !coords.isEmpty else {
            return CLLocationCoordinate2D(latitude: 31.23, longitude: 121.47)
        }
        let centerLat = coords.map { $0.latitude }.reduce(0, +) / Double(coords.count)
        let centerLon = coords.map { $0.longitude }.reduce(0, +) / Double(coords.count)
        return CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // 地图
                LocationPickerMapView(
                    polygonCoordinates: polygonCoordinates,
                    centerCoordinate: centerCoordinate,
                    selectedLocation: $selectedLocation,
                    isLocationValid: $isLocationValid,
                    validateLocation: validateLocation
                )
                .ignoresSafeArea(edges: .bottom)

                // 底部确认栏
                VStack {
                    Spacer()

                    bottomBar
                }
            }
            .navigationTitle("选择建造位置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        onCancel()
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .alert("位置无效", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text("请在领地范围内选择位置")
            }
        }
    }

    // MARK: - 底部确认栏
    private var bottomBar: some View {
        VStack(spacing: 12) {
            // 提示文字
            if selectedLocation == nil {
                Text("点击地图选择建造位置")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            } else if !isLocationValid {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(ApocalypseTheme.danger)

                    Text("该位置不在领地范围内")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.danger)
                }
            } else {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(ApocalypseTheme.success)

                    Text("位置有效")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.success)
                }
            }

            // 确认按钮
            Button {
                confirmLocation()
            } label: {
                Text("确认位置")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isLocationValid
                               ? ApocalypseTheme.primary
                               : ApocalypseTheme.textSecondary)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(!isLocationValid)
        }
        .padding()
        .background(
            ApocalypseTheme.cardBackground
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: -5)
        )
    }

    // MARK: - Methods

    /// 验证位置是否在领地内
    private func validateLocation(_ location: CLLocationCoordinate2D) -> Bool {
        territoryManager.isPointInPolygon(
            point: location,
            polygon: polygonCoordinates
        )
    }

    /// 确认位置
    private func confirmLocation() {
        guard let location = selectedLocation, isLocationValid else {
            showError = true
            return
        }

        onSelect(location)
    }
}

// MARK: - 位置选择地图视图（UIKit 封装）
struct LocationPickerMapView: UIViewRepresentable {

    let polygonCoordinates: [CLLocationCoordinate2D]
    let centerCoordinate: CLLocationCoordinate2D
    @Binding var selectedLocation: CLLocationCoordinate2D?
    @Binding var isLocationValid: Bool
    let validateLocation: (CLLocationCoordinate2D) -> Bool

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = false
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false

        // 添加点击手势
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        mapView.addGestureRecognizer(tapGesture)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 更新协调器引用
        context.coordinator.parent = self

        // 移除旧的覆盖物（保留选择点的标注）
        mapView.removeOverlays(mapView.overlays)

        // 添加领地多边形
        if !polygonCoordinates.isEmpty {
            let polygon = MKPolygon(coordinates: polygonCoordinates, count: polygonCoordinates.count)
            mapView.addOverlay(polygon)

            // 设置地图区域（只在首次加载时）
            if context.coordinator.isFirstLoad {
                let region = MKCoordinateRegion(
                    center: centerCoordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
                )
                mapView.setRegion(region, animated: false)
                context.coordinator.isFirstLoad = false
            }
        }

        // 更新选择点标注
        updateSelectedAnnotation(mapView, context: context)
    }

    private func updateSelectedAnnotation(_ mapView: MKMapView, context: Context) {
        // 移除旧的选择点标注
        let existingAnnotations = mapView.annotations.filter { $0 is SelectionAnnotation }
        mapView.removeAnnotations(existingAnnotations)

        // 添加新的选择点标注
        if let location = selectedLocation {
            let annotation = SelectionAnnotation(coordinate: location, isValid: isLocationValid)
            mapView.addAnnotation(annotation)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: LocationPickerMapView
        var isFirstLoad = true

        init(_ parent: LocationPickerMapView) {
            self.parent = parent
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }

            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)

            // 更新选择的位置
            parent.selectedLocation = coordinate
            parent.isLocationValid = parent.validateLocation(coordinate)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = UIColor(ApocalypseTheme.primary).withAlphaComponent(0.15)
                renderer.strokeColor = UIColor(ApocalypseTheme.primary)
                renderer.lineWidth = 2
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let selectionAnnotation = annotation as? SelectionAnnotation else {
                return nil
            }

            let identifier = "SelectionAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: selectionAnnotation, reuseIdentifier: identifier)
            } else {
                annotationView?.annotation = selectionAnnotation
            }

            // 根据是否有效设置颜色
            if selectionAnnotation.isValid {
                annotationView?.markerTintColor = UIColor(ApocalypseTheme.success)
                annotationView?.glyphImage = UIImage(systemName: "checkmark")
            } else {
                annotationView?.markerTintColor = UIColor(ApocalypseTheme.danger)
                annotationView?.glyphImage = UIImage(systemName: "xmark")
            }

            return annotationView
        }
    }
}

// MARK: - 选择点标注
class SelectionAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let isValid: Bool

    init(coordinate: CLLocationCoordinate2D, isValid: Bool) {
        self.coordinate = coordinate
        self.isValid = isValid
        super.init()
    }
}

// MARK: - Preview
#Preview {
    let sampleTerritory = Territory(
        id: UUID(),
        userId: UUID(),
        name: "测试领地",
        path: [
            ["lat": 31.2304, "lon": 121.4737],
            ["lat": 31.2314, "lon": 121.4737],
            ["lat": 31.2314, "lon": 121.4747],
            ["lat": 31.2304, "lon": 121.4747]
        ],
        area: 1000,
        pointCount: 4,
        isActive: true,
        startedAt: nil,
        completedAt: nil,
        createdAt: Date()
    )

    BuildingLocationPickerView(
        territory: sampleTerritory,
        onSelect: { _ in },
        onCancel: {}
    )
}
