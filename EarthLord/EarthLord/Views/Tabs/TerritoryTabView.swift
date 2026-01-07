//
//  TerritoryTabView.swift
//  EarthLord
//
//  领地管理页面 - 显示我的领地列表和统计信息
//

import SwiftUI

struct TerritoryTabView: View {

    // MARK: - Properties

    /// 领地管理器
    private let territoryManager = TerritoryManager.shared

    /// 我的领地列表
    @State private var myTerritories: [Territory] = []

    /// 是否正在加载
    @State private var isLoading: Bool = false

    /// 错误信息
    @State private var errorMessage: String?

    /// 选中的领地（用于显示详情）
    @State private var selectedTerritory: Territory?

    // MARK: - Computed Properties

    /// 总面积
    private var totalArea: Double {
        myTerritories.reduce(0) { $0 + $1.area }
    }

    /// 格式化总面积
    private var formattedTotalArea: String {
        if totalArea >= 1_000_000 {
            return String(format: "%.2f km²", totalArea / 1_000_000)
        } else if totalArea >= 10_000 {
            return String(format: "%.2f 万m²", totalArea / 10_000)
        } else {
            return String(format: "%.0f m²", totalArea)
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景色
                ApocalypseTheme.background
                    .ignoresSafeArea()

                if isLoading && myTerritories.isEmpty {
                    // 首次加载中
                    loadingView
                } else if myTerritories.isEmpty {
                    // 空状态
                    emptyStateView
                } else {
                    // 领地列表
                    territoryListView
                }
            }
            .navigationTitle("我的领地")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await loadMyTerritories() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(ApocalypseTheme.primary)
                    }
                    .disabled(isLoading)
                }
            }
        }
        .onAppear {
            if myTerritories.isEmpty {
                Task { await loadMyTerritories() }
            }
        }
        .sheet(item: $selectedTerritory) { territory in
            TerritoryDetailView(
                territory: territory,
                onDelete: {
                    // 删除后刷新列表
                    Task { await loadMyTerritories() }
                }
            )
        }
    }

    // MARK: - 加载中视图

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                .scaleEffect(1.5)

            Text("加载中...")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    // MARK: - 空状态视图

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "flag.slash")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("还没有领地")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("前往地图页面开始圈地吧！\n走完一圈回到起点即可占领领地")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 8)
            }
        }
        .padding()
    }

    // MARK: - 领地列表视图

    private var territoryListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // 统计卡片
                statisticsCard

                // 领地卡片列表
                ForEach(myTerritories) { territory in
                    TerritoryCardView(territory: territory)
                        .onTapGesture {
                            selectedTerritory = territory
                        }
                }
            }
            .padding()
        }
        .refreshable {
            await loadMyTerritories()
        }
    }

    // MARK: - 统计卡片

    private var statisticsCard: some View {
        HStack(spacing: 20) {
            // 领地数量
            VStack(spacing: 4) {
                Text("\(myTerritories.count)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(ApocalypseTheme.primary)

                Text("领地数量")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)

            // 分隔线
            Rectangle()
                .fill(ApocalypseTheme.textSecondary.opacity(0.3))
                .frame(width: 1, height: 50)

            // 总面积
            VStack(spacing: 4) {
                Text(formattedTotalArea)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(ApocalypseTheme.primary)

                Text("总面积")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Methods

    /// 加载我的领地
    private func loadMyTerritories() async {
        isLoading = true
        errorMessage = nil

        do {
            myTerritories = try await territoryManager.loadMyTerritories()
        } catch {
            errorMessage = error.localizedDescription
            print("❌ [领地Tab] 加载失败: \(error.localizedDescription)")
        }

        isLoading = false
    }
}

// MARK: - 领地卡片视图

struct TerritoryCardView: View {

    let territory: Territory

    var body: some View {
        HStack(spacing: 12) {
            // 左侧图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: "flag.fill")
                    .font(.system(size: 20))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            // 中间信息
            VStack(alignment: .leading, spacing: 4) {
                Text(territory.displayName)
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    // 面积
                    Label(territory.formattedArea, systemImage: "square.dashed")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    // 点数
                    if let pointCount = territory.pointCount {
                        Label("\(pointCount)点", systemImage: "mappin.and.ellipse")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }

                // 创建时间
                Text(territory.formattedCreatedAt)
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.7))
            }

            Spacer()

            // 右侧箭头
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    TerritoryTabView()
}
