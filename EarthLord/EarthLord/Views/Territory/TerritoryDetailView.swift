//
//  TerritoryDetailView.swift
//  EarthLord
//
//  领地详情页 - 全屏地图布局，显示领地信息、建筑列表和管理功能
//

import SwiftUI
import MapKit

struct TerritoryDetailView: View {

    // MARK: - Properties

    /// 领地数据
    @State private var territory: Territory

    /// 删除回调
    var onDelete: (() -> Void)?

    /// 环境变量 - 关闭 sheet
    @Environment(\.dismiss) private var dismiss

    /// 领地管理器
    private let territoryManager = TerritoryManager.shared

    /// 建筑管理器
    private let buildingManager = BuildingManager.shared

    /// 是否显示设置菜单
    @State private var showSettingsDialog = false

    /// 是否显示删除确认
    @State private var showDeleteAlert = false

    /// 是否正在删除
    @State private var isDeleting = false

    /// 是否显示重命名弹窗
    @State private var showRenameAlert = false

    /// 新名称输入
    @State private var newName = ""

    /// 是否正在重命名
    @State private var isRenaming = false

    /// 底部面板是否展开
    @State private var isPanelExpanded = true

    /// 是否显示建筑浏览器
    @State private var showBuildingBrowser = false

    /// 选中的建筑模板（用于建造确认）
    @State private var selectedTemplateForConstruction: BuildingTemplate?

    /// 领地内的建筑列表
    @State private var buildings: [PlayerBuilding] = []

    /// 是否正在加载建筑
    @State private var isLoadingBuildings = false

    /// 错误信息
    @State private var errorMessage: String?

    /// 显示错误提示
    @State private var showError = false

    // MARK: - Computed Properties

    /// 领地多边形坐标
    private var polygonCoordinates: [CLLocationCoordinate2D] {
        territory.toCoordinates()
    }

    /// 领地中心点
    private var centerCoordinate: CLLocationCoordinate2D {
        let coords = polygonCoordinates
        if !coords.isEmpty {
            let centerLat = coords.map { $0.latitude }.reduce(0, +) / Double(coords.count)
            let centerLon = coords.map { $0.longitude }.reduce(0, +) / Double(coords.count)
            return CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
        }
        return CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737)
    }

    // MARK: - Initialization

    init(territory: Territory, onDelete: (() -> Void)? = nil) {
        _territory = State(initialValue: territory)
        self.onDelete = onDelete
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 底层：全屏地图
            TerritoryMapView(
                polygonCoordinates: polygonCoordinates,
                buildings: buildings,
                getTemplate: { buildingManager.getTemplate(id: $0) },
                centerCoordinate: centerCoordinate,
                spanDelta: calculateSpanDelta()
            )
            .ignoresSafeArea()

            // 顶层：UI 元素
            VStack(spacing: 0) {
                // 顶部工具栏
                TerritoryToolbarView(
                    territoryName: territory.displayName,
                    onBack: { dismiss() },
                    onSettings: { showSettingsMenu() },
                    onBuild: { showBuildingBrowser = true }
                )
                .padding(.top, 50)

                Spacer()

                // 底部信息面板
                bottomPanel
            }
        }
        .onAppear {
            loadBuildings()
            // 检查并完成已到时间的建筑
            Task {
                await buildingManager.checkAndCompleteBuildings()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .buildingUpdated)) { _ in
            loadBuildings()
        }
        .sheet(isPresented: $showBuildingBrowser) {
            BuildingBrowserView(
                territory: territory,
                onDismiss: { showBuildingBrowser = false },
                onSelectTemplate: { template in
                    // 关闭浏览器后延迟打开建造确认页
                    showBuildingBrowser = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        selectedTemplateForConstruction = template
                    }
                }
            )
        }
        .sheet(item: $selectedTemplateForConstruction) { template in
            BuildingPlacementView(
                template: template,
                territory: territory,
                onDismiss: { selectedTemplateForConstruction = nil },
                onConstructionStarted: { building in
                    selectedTemplateForConstruction = nil
                    buildings.append(building)
                }
            )
        }
        .confirmationDialog("领地设置", isPresented: $showSettingsDialog, titleVisibility: .visible) {
            Button("重命名领地") {
                newName = territory.name ?? ""
                showRenameAlert = true
            }
            Button("删除领地", role: .destructive) {
                showDeleteAlert = true
            }
            Button("取消", role: .cancel) {}
        }
        .alert("重命名领地", isPresented: $showRenameAlert) {
            TextField("输入新名称", text: $newName)
            Button("取消", role: .cancel) {
                newName = ""
            }
            Button("确定") {
                Task { await renameTerritory() }
            }
            .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
        } message: {
            Text("为你的领地起一个响亮的名字")
        }
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                Task { await deleteTerritory() }
            }
        } message: {
            Text("删除后将无法恢复，确定要删除这块领地吗？")
        }
        .alert("操作失败", isPresented: $showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "未知错误")
        }
    }

    // MARK: - 底部面板

    private var bottomPanel: some View {
        VStack(spacing: 0) {
            // 折叠/展开手柄
            panelHandle

            if isPanelExpanded {
                // 面板内容
                ScrollView {
                    VStack(spacing: 16) {
                        // 领地信息卡片
                        infoCard

                        // 建筑列表
                        buildingListSection

                        // 删除领地按钮
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            Label("删除领地", systemImage: "trash")
                                .foregroundColor(ApocalypseTheme.danger)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(ApocalypseTheme.danger.opacity(0.1))
                                .cornerRadius(12)
                        }
                    }
                    .padding()
                }
                .frame(maxHeight: 350)
            }
        }
        .background(
            ApocalypseTheme.cardBackground
                .cornerRadius(20, corners: [.topLeft, .topRight])
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: -5)
        )
    }

    // MARK: - 面板手柄
    private var panelHandle: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3)
                .fill(ApocalypseTheme.textSecondary.opacity(0.5))
                .frame(width: 40, height: 5)
                .padding(.top, 12)

            HStack {
                Text(isPanelExpanded ? "领地信息" : "点击展开")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Image(systemName: isPanelExpanded ? "chevron.down" : "chevron.up")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                isPanelExpanded.toggle()
            }
        }
    }

    // MARK: - 信息卡片

    private var infoCard: some View {
        VStack(spacing: 12) {
            // 信息行
            HStack {
                infoItem(icon: "square.dashed", title: "面积", value: territory.formattedArea)
                Spacer()
                infoItem(icon: "mappin.and.ellipse", title: "边界点", value: "\(territory.pointCount ?? 0)")
                Spacer()
                infoItem(icon: "building.2", title: "建筑", value: "\(buildings.count)")
            }

            Divider()
                .background(ApocalypseTheme.textSecondary.opacity(0.3))

            // 创建时间
            HStack {
                Label(territory.formattedCreatedAt, systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()

                // 圈地用时
                Label(territory.formattedDuration, systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
        .padding()
        .background(ApocalypseTheme.background.opacity(0.5))
        .cornerRadius(12)
    }

    /// 信息项
    private func infoItem(icon: String, title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(ApocalypseTheme.primary)

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text(title)
                .font(.caption2)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    // MARK: - 建筑列表区域

    private var buildingListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            HStack {
                Image(systemName: "building.2.fill")
                    .foregroundColor(ApocalypseTheme.primary)

                Text("建筑列表")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                if isLoadingBuildings {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            if buildings.isEmpty && !isLoadingBuildings {
                // 空状态
                VStack(spacing: 8) {
                    Image(systemName: "hammer")
                        .font(.system(size: 32))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Text("暂无建筑")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Text("点击右上角「建造」按钮开始建造")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                // 建筑列表
                ForEach(buildings) { building in
                    TerritoryBuildingRow(
                        building: building,
                        template: buildingManager.getTemplate(id: building.templateId),
                        onUpgrade: {
                            // TODO: 实现升级功能
                        },
                        onDemolish: {
                            Task { await demolishBuilding(building) }
                        }
                    )
                }
            }
        }
    }

    // MARK: - Methods

    /// 计算合适的地图缩放级别
    private func calculateSpanDelta() -> Double {
        let coords = polygonCoordinates
        guard !coords.isEmpty else { return 0.005 }

        let latitudes = coords.map { $0.latitude }
        let longitudes = coords.map { $0.longitude }
        let latSpan = (latitudes.max() ?? 0) - (latitudes.min() ?? 0)
        let lonSpan = (longitudes.max() ?? 0) - (longitudes.min() ?? 0)

        return max(latSpan, lonSpan) * 1.8 + 0.001
    }

    /// 显示设置菜单
    private func showSettingsMenu() {
        showSettingsDialog = true
    }

    /// 加载建筑列表
    private func loadBuildings() {
        isLoadingBuildings = true

        Task {
            do {
                buildings = try await buildingManager.loadBuildings(for: territory.id)
            } catch {
                print("❌ [领地详情] 加载建筑失败: \(error.localizedDescription)")
            }
            isLoadingBuildings = false
        }
    }

    /// 重命名领地
    private func renameTerritory() async {
        let trimmedName = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        isRenaming = true

        let success = await territoryManager.renameTerritory(
            territoryId: territory.id,
            newName: trimmedName
        )

        isRenaming = false

        if success {
            // 更新本地数据
            territory.name = trimmedName

            // 发送通知刷新列表
            NotificationCenter.default.post(name: .territoryUpdated, object: territory.id)
        } else {
            errorMessage = "重命名失败，请稍后重试"
            showError = true
        }

        newName = ""
    }

    /// 删除领地
    private func deleteTerritory() async {
        isDeleting = true

        let success = await territoryManager.deleteTerritory(territoryId: territory.id)

        isDeleting = false

        if success {
            // 发送通知刷新列表
            NotificationCenter.default.post(name: .territoryUpdated, object: territory.id)

            // 删除成功，关闭详情页并刷新列表
            onDelete?()
            dismiss()
        } else {
            errorMessage = "删除失败，请稍后重试"
            showError = true
        }
    }

    /// 拆除建筑
    private func demolishBuilding(_ building: PlayerBuilding) async {
        do {
            try await buildingManager.demolishBuilding(buildingId: building.id)
            buildings.removeAll { $0.id == building.id }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - 圆角扩展
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
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
