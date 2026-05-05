import SwiftUI

/// PacePlan の目標ペース vs 実走ラップを行ごとに比較する表。
/// Lap | Target | Actual | Δ | Banked (累積)。
struct PlanVsActualTable: View {
    let deltas: [AdvancedAnalytics.PlanLapDelta]
    let planName: String

    var body: some View {
        if deltas.isEmpty {
            Text("— no laps to compare against \(planName)")
                .appText(.bodyXs)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
        } else {
            content
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            header
            Divider().padding(.leading, 12)
            ForEach(Array(deltas.enumerated()), id: \.element.id) { idx, d in
                row(d)
                if idx < deltas.count - 1 {
                    Divider().padding(.leading, 12)
                }
            }
        }
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Lap").frame(width: 36, alignment: .leading)
            Text("Target").frame(maxWidth: .infinity, alignment: .trailing)
            Text("Actual").frame(maxWidth: .infinity, alignment: .trailing)
            Text("Δ").frame(width: 56, alignment: .trailing)
            Text("Banked").frame(width: 64, alignment: .trailing)
        }
        .appText(.bodyXs)
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func row(_ d: AdvancedAnalytics.PlanLapDelta) -> some View {
        HStack(spacing: 8) {
            Text("\(d.lapIndex)")
                .appText(.codeBaseBold)
                .foregroundStyle(Color.textPrimary)
                .frame(width: 36, alignment: .leading)
            Text(formatTime(d.targetSec))
                .appText(.codeXs)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text(formatTime(d.actualSec))
                .appText(.codeXsBold)
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text(PaceUtils.formatSignedDuration(d.deltaSec))
                .appText(.codeXxs)
                .foregroundStyle(color(d.deltaSec))
                .frame(width: 56, alignment: .trailing)
            Text(PaceUtils.formatSignedDuration(d.cumulativeSec))
                .appText(.codeXxs)
                .foregroundStyle(color(d.cumulativeSec))
                .frame(width: 64, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func color(_ sec: Double) -> Color {
        if sec < -2 { return .cat10K }
        if sec > 2 { return .catFullMarathon }
        return .secondary
    }

    private func formatTime(_ sec: Double) -> String {
        let s = Int(sec.rounded())
        let h = s / 3600
        let m = (s % 3600) / 60
        let r = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, r) }
        return String(format: "%d:%02d", m, r)
    }
}
