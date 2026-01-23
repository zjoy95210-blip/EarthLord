//
//  BuildingCard.swift
//  EarthLord
//
//  建筑卡片组件
//

import SwiftUI

struct BuildingCard: View {

    // MARK: - Properties

    let template: BuildingTemplate
    let onTap: () -> Void

    /// 当前领地中该建筑的数量
    var existingCount: Int = 0

    // MARK: - Computed Properties

    /// 是否已达上限
    private var isMaxReached: Bool {
        existingCount >= template.maxPerTerritory
    }

    /// 分类颜色
    private var categoryColor: Color {
        Color(hex: template.category.colorHex)
    }

    // MARK: - Body

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // 顶部：图标和分类标签
                HStack {
                    // 建筑图标
                    ZStack {
                        Circle()
                            .fill(categoryColor.opacity(0.2))
                            .frame(width: 44, height: 44)

                        Image(systemName: template.iconName)
                            .font(.system(size: 20))
                            .foregroundColor(categoryColor)
                    }

                    Spacer()

                    // 分类标签
                    Text(template.category.displayName)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(categoryColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(categoryColor.opacity(0.15))
                        .cornerRadius(8)
                }

                // 建筑名称
                Text(template.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .lineLimit(1)

                // 描述
                Text(template.description)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .lineLimit(2)
                    .frame(height: 32, alignment: .top)

                Spacer(minLength: 4)

                // 底部：建造时间和数量
                HStack {
                    // 建造时间
                    Label(template.formattedBuildTime, systemImage: "clock")
                        .font(.caption2)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Spacer()

                    // 数量限制
                    if isMaxReached {
                        Text("已达上限")
                            .font(.caption2)
                            .foregroundColor(ApocalypseTheme.danger)
                    } else {
                        Text("\(existingCount)/\(template.maxPerTerritory)")
                            .font(.caption2)
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                }
            }
            .padding(12)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isMaxReached
                            ? ApocalypseTheme.danger.opacity(0.3)
                            : categoryColor.opacity(0.2),
                        lineWidth: 1
                    )
            )
            .opacity(isMaxReached ? 0.6 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isMaxReached)
    }
}

// MARK: - Preview
#Preview {
    let sampleTemplate = BuildingTemplate(
        id: "campfire",
        name: "篝火",
        description: "提供基础照明和温暖，是生存的起点",
        category: .survival,
        tier: 1,
        maxPerTerritory: 2,
        buildTime: 30,
        requiredMaterials: [],
        maxLevel: 3,
        iconName: "flame.fill",
        effects: nil
    )

    ScrollView {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            BuildingCard(template: sampleTemplate, onTap: {})
            BuildingCard(template: sampleTemplate, onTap: {}, existingCount: 2)
        }
        .padding()
    }
    .background(ApocalypseTheme.background)
}
