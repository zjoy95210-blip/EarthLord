//
//  CategoryButton.swift
//  EarthLord
//
//  建筑分类按钮组件
//

import SwiftUI

// MARK: - 建筑分类筛选枚举
enum BuildingCategoryFilter: String, CaseIterable {
    case all = "all"
    case survival = "survival"
    case storage = "storage"
    case production = "production"
    case energy = "energy"

    var displayName: String {
        switch self {
        case .all: return "全部"
        case .survival: return "生存"
        case .storage: return "储存"
        case .production: return "生产"
        case .energy: return "能源"
        }
    }

    var iconName: String {
        switch self {
        case .all: return "square.grid.2x2.fill"
        case .survival: return "flame.fill"
        case .storage: return "shippingbox.fill"
        case .production: return "gearshape.2.fill"
        case .energy: return "bolt.fill"
        }
    }

    /// 转换为 BuildingCategory（全部时返回 nil）
    var toCategory: BuildingCategory? {
        switch self {
        case .all: return nil
        case .survival: return .survival
        case .storage: return .storage
        case .production: return .production
        case .energy: return .energy
        }
    }
}

// MARK: - 分类按钮组件
struct CategoryButton: View {

    let filter: BuildingCategoryFilter
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: filter.iconName)
                    .font(.system(size: 14))

                Text(filter.displayName)
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected
                    ? ApocalypseTheme.primary
                    : ApocalypseTheme.cardBackground
            )
            .foregroundColor(
                isSelected
                    ? .white
                    : ApocalypseTheme.textSecondary
            )
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isSelected
                            ? Color.clear
                            : ApocalypseTheme.textSecondary.opacity(0.3),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 分类按钮组
struct CategoryButtonGroup: View {

    @Binding var selectedFilter: BuildingCategoryFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(BuildingCategoryFilter.allCases, id: \.self) { filter in
                    CategoryButton(
                        filter: filter,
                        isSelected: selectedFilter == filter
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedFilter = filter
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        CategoryButton(
            filter: .all,
            isSelected: true
        ) {}

        CategoryButton(
            filter: .survival,
            isSelected: false
        ) {}

        CategoryButtonGroup(
            selectedFilter: .constant(.all)
        )
    }
    .padding()
    .background(ApocalypseTheme.background)
}
