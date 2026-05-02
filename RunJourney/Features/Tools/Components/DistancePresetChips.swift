import SwiftUI

/// 距離プリセットチップ行: `Full / Half / Custom` (+ オプションで 5K / 10K)。
/// バインドされた km 値 (Double) を直接書き換える。Custom は @AppStorage("customDistanceKm") を採用。
struct DistancePresetChips: View {
    @Binding var distanceKm: Double
    var includes5K10K: Bool = true

    @AppStorage("customDistanceKm") private var customDistanceKm: Double = 10.0

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if includes5K10K {
                    chip(label: "5K", value: 5)
                    chip(label: "10K", value: 10)
                }
                chip(label: "Half", value: 21.0975)
                chip(label: "Full", value: 42.195)
                chip(label: "Custom", value: customDistanceKm)
            }
        }
    }

    private func chip(label: String, value: Double) -> some View {
        Button {
            distanceKm = value
        } label: {
            Text(label)
                .appText(.displayXs)
                .foregroundStyle(isActive(value) ? Color.bgPrimary : Color.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    isActive(value) ? Color.accentPrimary : Color.bgSecondary,
                    in: RoundedRectangle(cornerRadius: 10)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(isActive(value) ? .clear : .white.opacity(0.1), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }

    private func isActive(_ v: Double) -> Bool {
        abs(distanceKm - v) < 0.0001
    }
}
