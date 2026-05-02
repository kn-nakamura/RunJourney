import SwiftUI

/// 再生中の現在ペース・心拍・標高・距離・経過時間をオーバーレイで表示。
struct PlaybackHUD: View {
    let controller: PlaybackController
    let race: Race?

    @AppStorage("distanceUnit") private var distanceUnitRaw: String = DistanceUnit.km.rawValue
    private var unit: DistanceUnit { DistanceUnit.resolve(distanceUnitRaw) }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // 経過時間 / 総時間
            VStack(alignment: .leading, spacing: 1) {
                Text(formatDuration(controller.currentTime))
                    .appText(.codeLg)
                    .foregroundStyle(Color.accentPrimary)
                Text("/ \(formatDuration(controller.totalDuration))")
                    .appText(.codeXxs)
                    .foregroundStyle(.secondary)
            }
            Divider().frame(height: 36).background(.white.opacity(0.15))
            // 距離
            VStack(alignment: .leading, spacing: 2) {
                Text("Distance")
                    .appText(.bodyXs)
                    .foregroundStyle(.secondary)
                Text(distanceText)
                    .appText(.codeBaseBold)
                    .foregroundStyle(Color.textPrimary)
            }
            // ペース（直近の速度から逆算）
            VStack(alignment: .leading, spacing: 2) {
                Text("Pace")
                    .appText(.bodyXs)
                    .foregroundStyle(.secondary)
                Text(paceText)
                    .appText(.codeBaseBold)
                    .foregroundStyle(Color.textPrimary)
            }
            // 心拍
            if hrText != nil {
                VStack(alignment: .leading, spacing: 2) {
                    Text("HR")
                        .appText(.bodyXs)
                        .foregroundStyle(.secondary)
                    Text(hrText ?? "—")
                        .appText(.codeBaseBold)
                        .foregroundStyle(Color.catFullMarathon)
                }
            }
            // 標高
            if elevText != nil {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Elevation")
                        .appText(.bodyXs)
                        .foregroundStyle(.secondary)
                    Text(elevText ?? "—")
                        .appText(.codeBaseBold)
                        .foregroundStyle(Color.cat10K)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.06))
        )
    }

    private var distanceText: String {
        guard let p = controller.currentPoint else { return "—" }
        // メートル表示は短距離時のみ。それ以外は km / mi で表示。
        if unit == .km, p.distanceM < 1000 { return String(format: "%.0f m", p.distanceM) }
        return PaceUtils.formatDistance(km: p.distanceM / 1000, in: unit)
    }

    private var paceText: String {
        guard let p = controller.currentPoint else { return "—" }
        if let speed = p.speedMs, speed > 0.1 {
            // 1km をその速度で走るのに必要な秒数
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
        return String(format: "%.0f m", alt)
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
