//
//  POIProximityPopup.swift
//  EarthLord
//
//  POI 接近弹窗
//  玩家进入 POI 50米范围时显示
//

import SwiftUI
import CoreLocation

/// POI 接近弹窗
struct POIProximityPopup: View {

    // MARK: - Properties

    let poi: ScavengePOI
    @Binding var isScavenging: Bool
    let onScavenge: () async -> Void
    let onDismiss: () -> Void

    // MARK: - State

    @State private var pulseAnimation: Bool = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 20) {
            // 顶部抓手
            RoundedRectangle(cornerRadius: 3)
                .fill(ApocalypseTheme.textMuted)
                .frame(width: 40, height: 5)
                .padding(.top, 10)

            // POI 信息
            HStack(spacing: 14) {
                // 图标（带脉冲动画）
                ZStack {
                    // 脉冲圆
                    Circle()
                        .fill(poi.category.color.opacity(0.3))
                        .frame(width: 70, height: 70)
                        .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                        .opacity(pulseAnimation ? 0.0 : 0.5)

                    // 主圆
                    Circle()
                        .fill(poi.category.color.opacity(0.15))
                        .frame(width: 60, height: 60)

                    Image(systemName: poi.category.iconName)
                        .font(.system(size: 28))
                        .foregroundColor(poi.category.color)
                }

                // 文字信息
                VStack(alignment: .leading, spacing: 6) {
                    Text(poi.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        // 类型
                        Text(poi.category.displayName)
                            .font(.system(size: 13))
                            .foregroundColor(poi.category.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(poi.category.color.opacity(0.15))
                            )

                        // 距离
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 10))
                            Text(poi.formattedDistance)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(ApocalypseTheme.success)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 20)

            // 提示文字
            Text("您已进入搜刮范围")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)

            // 按钮区域
            HStack(spacing: 12) {
                // 稍后按钮
                Button {
                    onDismiss()
                } label: {
                    Text("稍后")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(ApocalypseTheme.textMuted.opacity(0.5), lineWidth: 1)
                        )
                }
                .disabled(isScavenging)

                // 搜刮按钮
                Button {
                    Task {
                        await onScavenge()
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isScavenging {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.9)
                            Text("搜刮中...")
                        } else {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16, weight: .semibold))
                            Text("立即搜刮")
                        }
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isScavenging ? ApocalypseTheme.textMuted : ApocalypseTheme.primary)
                    )
                }
                .disabled(isScavenging)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(ApocalypseTheme.cardBackground)
        .onAppear {
            startPulseAnimation()
        }
    }

    /// 启动脉冲动画
    private func startPulseAnimation() {
        withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
            pulseAnimation = true
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        ApocalypseTheme.background
            .ignoresSafeArea()

        VStack {
            Spacer()

            POIProximityPopup(
                poi: ScavengePOI(
                    id: "test_poi",
                    name: "测试超市",
                    category: .supermarket,
                    coordinate: .init(latitude: 0, longitude: 0),
                    status: .available,
                    lastScavengedAt: nil,
                    distanceToPlayer: 32
                ),
                isScavenging: .constant(false),
                onScavenge: {},
                onDismiss: {}
            )
        }
    }
}
