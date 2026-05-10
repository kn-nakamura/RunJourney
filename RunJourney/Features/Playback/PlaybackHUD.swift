import SwiftUI

/// 再生中の現在ペース・心拍・標高・距離・経過時間をオーバーレイで表示。
/// 経過/総時間は左固定。Dist / Pace / HR / Alt は等幅 4 カラムで右揃え、単位は固定幅。
struct PlaybackHUD: View {
    let controller: PlaybackController
    let race: Race?

    @AppStorage("distanceUnit") private var distanceUnitRaw: String = DistanceUnit.km.rawValue
    private var unit: DistanceUnit { DistanceUnit.resolve(distanceUnitRaw) }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // 経過時間 / 総時間 — 固定幅78pt
            VStack(alignment: .leading, spacing: 0) {
                Text(PaceUtils.formatDuration(controller.currentTime))
                    .appText(.codeSm)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .foregroundStyle(Color.accentPrimary)
                Text("/ \(PaceUtils.formatDuration(controller.totalDuration))")
                    .appText(.codeXxs)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 78, alignment: .leading)

            hudDivider

            // Dist / Pace / HR / Alt: 4 等幅カラム、右揃え、単位は固定位置
            HStack(alignment: .center, spacing: 6) {
                metricColumn(label: "Dist", number: distanceNumberText, unit: distanceUnitText)
                metricColumn(label: "Pace", number: paceNumberText,     unit: paceUnitText)
                metricColumn(label: "HR",   number: hrNumberText,       unit: "bpm",
                             numberColor: Color.catFullMarathon)
                metricColumn(label: "Alt",  number: altNumberText,      unit: "m",
                             numberColor: Color.cat10K)
            }
            .frame(maxWidth: .infinity)
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

    /// 4 等幅カラムの 1 列。number は右側、unit は固定で number の右隣に貼り付く。
    /// number だけが値更新で変化し、unit は同じ位置で動かない。
    @ViewBuilder
    private func metricColumn(
        label: String,
        number: String,
        unit: String,
        numberColor: Color = Color.textPrimary
    ) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(label)
                .appText(.bodyXs)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Spacer(minLength: 0)
                Text(number)
                    .appText(.codeSm)
                    .lineLimit(1)
                    .foregroundStyle(numberColor)
                Text(unit)
                    .appText(.bodyXs)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Computed values (number / unit を分離)

    /// 距離の数値部のみ。単位 (km / mi / m) は別 Text で固定表示する。
    private var distanceNumberText: String {
        guard let p = controller.currentPoint else { return "—" }
        if unit == .km, p.distanceM < 1000 {
            return String(format: "%.0f", p.distanceM)
        }
        let km = p.distanceM / 1000
        let displayed = km.displayed(in: unit)
        // 999.999 まで対応するため小数 3 桁を確保。
        return String(format: "%.3f", displayed)
    }

    /// 距離の単位部 (km / mi / m)。1000m 未満で km モードの時のみ "m"。
    private var distanceUnitText: String {
        guard let p = controller.currentPoint else { return unit.label }
        if unit == .km, p.distanceM < 1000 { return "m" }
        return unit.label
    }

    private var paceNumberText: String {
        guard let p = controller.currentPoint, let speed = p.speedMs, speed > 0.1 else { return "—" }
        let secPerKm = 1000.0 / speed
        let displayed = PaceUtils.paceSecondsPerUnit(secPerKm: Int(secPerKm.rounded()), in: unit)
        let m = displayed / 60
        let s = displayed % 60
        return String(format: "%d:%02d", m, s)
    }

    private var paceUnitText: String { unit.perLabel }

    private var hrNumberText: String {
        guard let hr = controller.currentPoint?.heartRate, hr > 0 else { return "—" }
        return "\(hr)"
    }

    private var altNumberText: String {
        guard let alt = controller.currentPoint?.altitudeM else { return "—" }
        return String(format: "%.0f", alt)
    }

}
