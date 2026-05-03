import SwiftUI

/// 再生中の現在ペース・心拍・標高・距離・経過時間をオーバーレイで表示。
/// 各列は固定幅 (frame(width:)) なので値が変わっても他列の位置が動かない。
struct PlaybackHUD: View {
    let controller: PlaybackController
    let race: Race?

    @AppStorage("distanceUnit") private var distanceUnitRaw: String = DistanceUnit.km.rawValue
    private var unit: DistanceUnit { DistanceUnit.resolve(distanceUnitRaw) }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // 経過時間 / 総時間 — 固定幅78pt
            VStack(alignment: .leading, spacing: 0) {
                Text(formatDuration(controller.currentTime))
                    .appText(.codeSm)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .foregroundStyle(Color.accentPrimary)
                Text("/ \(formatDuration(controller.totalDuration))")
                    .appText(.codeXxs)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 78, alignment: .leading)

            hudDivider

            metricColumn(label: "Dist",  value: distanceText, width: 66)
            metricColumn(label: "Pace",  value: paceText,     width: 62)

            if let hr = hrText {
                metricColumn(label: "HR",  value: hr,   width: 62, valueColor: Color.catFullMarathon)
            }
            if let elev = elevText {
                metricColumn(label: "Alt", value: elev, width: 46, valueColor: Color.cat10K)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.06)))
    }

    // MARK: - Sub-views

    private var hudDivider: some View {
        Divider()
            .frame(height: 28)
            .background(.white.opacity(0.15))
            .padding(.horizontal, 8)
    }

    @ViewBuilder
    private func metricColumn(
        label: String,
        value: String,
        width: CGFloat,
        valueColor: Color = Color.textPrimary
    ) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .appText(.bodyXs)
                .foregroundStyle(.secondary)
            Text(value)
                .appText(.codeSm)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .foregroundStyle(valueColor)
        }
        // width: 固定幅でコンテンツが大きくなっても他列の位置が動かない
        .frame(width: width, alignment: .leading)
    }

    // MARK: - Computed values

    private var distanceText: String {
        guard let p = controller.currentPoint else { return "—" }
        if unit == .km, p.distanceM < 1000 { return String(format: "%.0fm", p.distanceM) }
        return PaceUtils.formatDistance(km: p.distanceM / 1000, in: unit)
    }

    private var paceText: String {
        guard let p = controller.currentPoint else { return "—" }
        if let speed = p.speedMs, speed > 0.1 {
            let secPerKm = 1000.0 / speed
            let displayed = PaceUtils.paceSecondsPerUnit(secPerKm: Int(secPerKm.rounded()), in: unit)
            let m = displayed / 60
            let s = displayed % 60
            return String(format: "%d:%02d\(unit.perLabel)", m, s)
        }
        return "—"
    }

    private var hrText: String? {
        guard let hr = controller.currentPoint?.heartRate, hr > 0 else { return nil }
        return "\(hr) bpm"
    }

    private var elevText: String? {
        guard let alt = controller.currentPoint?.altitudeM else { return nil }
        return String(format: "%.0fm", alt)
    }

    private func formatDuration(_ totalSec: Double) -> String {
        let s = Int(totalSec)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }
}
