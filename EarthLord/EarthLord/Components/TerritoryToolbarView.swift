//
//  TerritoryToolbarView.swift
//  EarthLord
//
//  领地详情页悬浮工具栏组件
//

import SwiftUI

struct TerritoryToolbarView: View {

    // MARK: - Properties

    let territoryName: String
    let onBack: () -> Void
    let onSettings: () -> Void
    let onBuild: () -> Void

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            // 返回按钮
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(ApocalypseTheme.cardBackground.opacity(0.9))
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            }

            // 领地名称
            Text(territoryName)
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .lineLimit(1)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(ApocalypseTheme.cardBackground.opacity(0.9))
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)

            Spacer()

            // 设置按钮
            Button(action: onSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(ApocalypseTheme.cardBackground.opacity(0.9))
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            }

            // 建造按钮
            Button(action: onBuild) {
                HStack(spacing: 6) {
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 14))

                    Text("建造")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(ApocalypseTheme.primary)
                .cornerRadius(20)
                .shadow(color: ApocalypseTheme.primary.opacity(0.4), radius: 4, x: 0, y: 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        ApocalypseTheme.background
            .ignoresSafeArea()

        VStack {
            TerritoryToolbarView(
                territoryName: "我的领地",
                onBack: {},
                onSettings: {},
                onBuild: {}
            )

            Spacer()
        }
    }
}
