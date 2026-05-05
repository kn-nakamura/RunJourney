import SwiftUI

/// 前半 / 後半時間とラベル ("Negative split" / "Positive split" / "Even split") を表示する 2 カラムカード。
/// `AdvancedAnalytics.halfSplit` の結果が無い場合は何も描かない。
struct HalfSplitPanel: View {
    let trackPoints: [TrackPoint]

    private var split: (firstHalfSec: Double, secondHalfSec: Double)? {
        AdvancedAnalytics.halfSplit(trackPoints)
    }

    var body: some View {
        if let s = split {
            content(first: s.firstHalfSec, second: s.secondHalfSec)
        } else {
            EmptyView()
        }
    }

    private func content(first: Double, second: Double) -> some View {
        let delta = second - first
        let label: (text: String, color: Color)
        if abs(delta) < 30 {
            label = ("Even split", .accentPrimary)
        } else if delta < 0 {
            label = ("Negative split", .cat10K)
        } else {
            label = ("Positive split", .catFullMarathon)
        }

        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                halfCell(title: "1st Half", time: first)
                halfCell(title: "2nd Half", time: second)
            }
            HStack(spacing: 10) {
                Text(label.text)
                    .appText(.bodySmBold)
                    .foregroundStyle(label.color)
                Spacer()
                Text("\u{0394} \(PaceUtils.formatSignedDuration(delta))")
                    .appText(.codeBaseBold)
                    .foregroundStyle(label.color)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func halfCell(title: String, time: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .appText(.bodyXs)
                .foregroundStyle(.tertiary)
            Text(formatDuration(time))
                .appText(.codeLg)
                .foregroundStyle(Color.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 10))
    }

    private func formatDuration(_ sec: Double) -> String {
        let s = Int(sec.rounded())
        let h = s / 3600
        let m = (s % 3600) / 60
        let r = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, r) }
        return String(format: "%d:%02d", m, r)
    }
}
