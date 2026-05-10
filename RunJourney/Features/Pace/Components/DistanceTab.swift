import SwiftUI

/// 距離プリセット (5K / 10K / Half / Full / Ultra100K / Custom) の選択チップ。
/// アクティブ時は accentPrimary、非アクティブは bgSecondary + 細い枠線。
struct DistanceTab: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .appText(.displayXs)
                .foregroundStyle(isActive ? Color.bgPrimary : Color.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    isActive ? Color.accentPrimary : Color.bgSecondary,
                    in: RoundedRectangle(cornerRadius: 10)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(isActive ? .clear : .white.opacity(0.1), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }
}
