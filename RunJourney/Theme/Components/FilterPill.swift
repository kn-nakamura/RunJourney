import SwiftUI

/// Capsule pill used in horizontal filter rows. Inactive uses bgSecondary;
/// active fills with the supplied accent color (category color or `.accentPrimary`).
struct FilterPill: View {
    let label: String
    let isActive: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .appText(.displayXs)
                .foregroundStyle(isActive ? Color.black : Color.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isActive ? color : Color.bgSecondary,
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .strokeBorder(isActive ? .clear : .white.opacity(0.1), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }
}
