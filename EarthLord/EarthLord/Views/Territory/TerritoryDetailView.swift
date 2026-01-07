//
//  TerritoryDetailView.swift
//  EarthLord
//
//  领地详情页 - 显示领地信息、地图预览和管理功能
//

import SwiftUI
import MapKit

struct TerritoryDetailView: View {

    // MARK: - Properties

    /// 领地数据
    let territory: Territory

    /// 删除回调
    var onDelete: (() -> Void)?

    /// 环境变量 - 关闭 sheet
    @Environment(\.dismiss) private var dismiss

    /// 领地管理器
    private let territoryManager = TerritoryManager.shared

    /// 是否显示删除确认
    @State private var showDeleteAlert: Bool = false

    /// 是否正在删除
    @State private var isDeleting: Bool = false

    /// 地图区域
    @State private var mapRegion: MKCoordinateRegion

    // MARK: - Initialization

    init(territory: Territory, onDelete: (() -> Void)? = nil) {
        self.territory = territory
        self.onDelete = onDelete

        // 计算地图中心和范围
        let coords = territory.toCoordinates()
        if !coords.isEmpty {
            let centerLat = coords.map { $0.latitude }.reduce(0, +) / Double(coords.count)
            let centerLon = coords.map { $0.longitude }.reduce(0, +) / Double(coords.count)

            let latitudes = coords.map { $0.latitude }
            let longitudes = coords.map { $0.longitude }
            let latSpan = (latitudes.max() ?? 0) - (latitudes.min() ?? 0)
            let lonSpan = (longitudes.max() ?? 0) - (longitudes.min() ?? 0)

            _mapRegion = State(initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                span: MKCoordinateSpan(
                    latitudeDelta: max(latSpan * 1.5, 0.005),
                    longitudeDelta: max(lonSpan * 1.5, 0.005)
                )
            ))
        } else {
            _mapRegion = State(initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 地图预览
                    mapPreview

                    // 领地信息卡片
                    infoCard

                    // 功能按钮区
                    actionButtons

                    // 未来功能占位
                    futureFeaturesCard
                }
                .padding()
            }
            .background(ApocalypseTheme.background)
            .navigationTitle(territory.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                Task { await deleteTerritory() }
            }
        } message: {
            Text("删除后将无法恢复，确定要删除这块领地吗？")
        }
    }

    // MARK: - 地图预览

    private var mapPreview: some View {
        Map(coordinateRegion: .constant(mapRegion))
            .overlay {
                // 绘制领地轮廓
                TerritoryPolygonOverlay(coordinates: territory.toCoordinates())
            }
            .frame(height: 200)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ApocalypseTheme.primary.opacity(0.3), lineWidth: 1)
            )
    }

    // MARK: - 信息卡片

    private var infoCard: some View {
        VStack(spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(ApocalypseTheme.primary)
                Text("领地信息")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Spacer()
            }

            Divider()
                .background(ApocalypseTheme.textSecondary.opacity(0.3))

            // 信息行
            infoRow(icon: "square.dashed", title: "面积", value: territory.formattedArea)
            infoRow(icon: "mappin.and.ellipse", title: "边界点数", value: "\(territory.pointCount ?? 0) 个")
            infoRow(icon: "clock", title: "圈地用时", value: territory.formattedDuration)
            infoRow(icon: "calendar", title: "创建时间", value: territory.formattedCreatedAt)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    /// 信息行
    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
    }

    // MARK: - 功能按钮

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // 删除按钮
            Button {
                showDeleteAlert = true
            } label: {
                HStack {
                    if isDeleting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "trash.fill")
                    }
                    Text(isDeleting ? "删除中..." : "删除领地")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .cornerRadius(12)
            }
            .disabled(isDeleting)
        }
    }

    // MARK: - 未来功能卡片

    private var futureFeaturesCard: some View {
        VStack(spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(ApocalypseTheme.warning)
                Text("即将推出")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Spacer()
            }

            Divider()
                .background(ApocalypseTheme.textSecondary.opacity(0.3))

            // 功能列表
            futureFeatureRow(icon: "pencil", title: "重命名领地", description: "为你的领地起一个响亮的名字")
            futureFeatureRow(icon: "building.2", title: "建筑系统", description: "在领地上建造各种设施")
            futureFeatureRow(icon: "arrow.left.arrow.right", title: "领地交易", description: "与其他玩家交易领地")
            futureFeatureRow(icon: "shield.fill", title: "领地防御", description: "设置防御措施保护领地")
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    /// 未来功能行
    private func futureFeatureRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(description)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            Text("敬请期待")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.warning)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(ApocalypseTheme.warning.opacity(0.2))
                .cornerRadius(4)
        }
    }

    // MARK: - Methods

    /// 删除领地
    private func deleteTerritory() async {
        isDeleting = true

        let success = await territoryManager.deleteTerritory(territoryId: territory.id)

        isDeleting = false

        if success {
            // 删除成功，关闭详情页并刷新列表
            onDelete?()
            dismiss()
        } else {
            // 删除失败，可以显示错误提示
            print("❌ [领地详情] 删除失败")
        }
    }
}

// MARK: - 领地多边形覆盖层

struct TerritoryPolygonOverlay: View {

    let coordinates: [CLLocationCoordinate2D]

    var body: some View {
        GeometryReader { geometry in
            if coordinates.count >= 3 {
                Path { path in
                    // 转换坐标到视图坐标
                    let points = coordinates.map { coord -> CGPoint in
                        // 简化的坐标转换（实际项目中需要更精确的转换）
                        let x = (coord.longitude - minLon) / (maxLon - minLon) * geometry.size.width
                        let y = (1 - (coord.latitude - minLat) / (maxLat - minLat)) * geometry.size.height
                        return CGPoint(x: x, y: y)
                    }

                    if let first = points.first {
                        path.move(to: first)
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                        path.closeSubpath()
                    }
                }
                .fill(Color.green.opacity(0.3))
                .overlay(
                    Path { path in
                        let points = coordinates.map { coord -> CGPoint in
                            let x = (coord.longitude - minLon) / (maxLon - minLon) * geometry.size.width
                            let y = (1 - (coord.latitude - minLat) / (maxLat - minLat)) * geometry.size.height
                            return CGPoint(x: x, y: y)
                        }

                        if let first = points.first {
                            path.move(to: first)
                            for point in points.dropFirst() {
                                path.addLine(to: point)
                            }
                            path.closeSubpath()
                        }
                    }
                    .stroke(Color.green, lineWidth: 2)
                )
            }
        }
    }

    private var minLat: Double {
        coordinates.map { $0.latitude }.min() ?? 0
    }

    private var maxLat: Double {
        coordinates.map { $0.latitude }.max() ?? 1
    }

    private var minLon: Double {
        coordinates.map { $0.longitude }.min() ?? 0
    }

    private var maxLon: Double {
        coordinates.map { $0.longitude }.max() ?? 1
    }
}

// MARK: - Preview

#Preview {
    TerritoryDetailView(
        territory: Territory(
            id: UUID(),
            userId: UUID(),
            name: "测试领地",
            path: [
                ["lat": 31.230, "lon": 121.473],
                ["lat": 31.231, "lon": 121.474],
                ["lat": 31.230, "lon": 121.475],
                ["lat": 31.229, "lon": 121.474]
            ],
            area: 1500,
            pointCount: 15,
            isActive: true,
            startedAt: Date().addingTimeInterval(-300),
            completedAt: Date(),
            createdAt: Date()
        )
    )
}
