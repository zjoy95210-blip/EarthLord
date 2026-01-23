//
//  ResourceRow.swift
//  EarthLord
//
//  资源行组件
//

import SwiftUI

// MARK: - 资源信息结构
struct ResourceInfo: Identifiable {
    let id = UUID()
    let itemId: String      // 物品ID
    let name: String        // 物品名称
    let iconName: String    // 图标名称
    let required: Int       // 需要数量
    let owned: Int          // 拥有数量

    /// 是否足够
    var isSufficient: Bool {
        owned >= required
    }

    /// 缺少数量
    var shortage: Int {
        max(0, required - owned)
    }
}

// MARK: - 资源行组件
struct ResourceRow: View {

    let resource: ResourceInfo

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(resource.isSufficient
                          ? ApocalypseTheme.success.opacity(0.2)
                          : ApocalypseTheme.danger.opacity(0.2))
                    .frame(width: 36, height: 36)

                Image(systemName: resource.iconName)
                    .font(.system(size: 16))
                    .foregroundColor(resource.isSufficient
                                     ? ApocalypseTheme.success
                                     : ApocalypseTheme.danger)
            }

            // 名称
            Text(resource.name)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            // 数量
            HStack(spacing: 4) {
                Text("\(resource.owned)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(resource.isSufficient
                                     ? ApocalypseTheme.success
                                     : ApocalypseTheme.danger)

                Text("/")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text("\(resource.required)")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 状态图标
            Image(systemName: resource.isSufficient
                  ? "checkmark.circle.fill"
                  : "xmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(resource.isSufficient
                                 ? ApocalypseTheme.success
                                 : ApocalypseTheme.danger)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - 资源列表视图
struct ResourceListView: View {

    let resources: [ResourceInfo]
    let title: String

    /// 是否所有资源都足够
    var allSufficient: Bool {
        resources.allSatisfy { $0.isSufficient }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            HStack {
                Image(systemName: "cube.box.fill")
                    .foregroundColor(ApocalypseTheme.primary)

                Text(title)
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                // 状态指示
                if allSufficient {
                    Label("材料充足", systemImage: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.success)
                } else {
                    Label("材料不足", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.danger)
                }
            }

            Divider()
                .background(ApocalypseTheme.textSecondary.opacity(0.3))

            // 资源列表
            ForEach(resources) { resource in
                ResourceRow(resource: resource)

                if resource.id != resources.last?.id {
                    Divider()
                        .background(ApocalypseTheme.textSecondary.opacity(0.2))
                }
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - Preview
#Preview {
    let resources = [
        ResourceInfo(
            itemId: "wood",
            name: "木材",
            iconName: "leaf.fill",
            required: 10,
            owned: 15
        ),
        ResourceInfo(
            itemId: "stone",
            name: "石头",
            iconName: "mountain.2.fill",
            required: 5,
            owned: 3
        ),
        ResourceInfo(
            itemId: "fiber",
            name: "纤维",
            iconName: "wind",
            required: 8,
            owned: 8
        )
    ]

    ScrollView {
        VStack(spacing: 20) {
            ResourceListView(resources: resources, title: "所需材料")
        }
        .padding()
    }
    .background(ApocalypseTheme.background)
}
