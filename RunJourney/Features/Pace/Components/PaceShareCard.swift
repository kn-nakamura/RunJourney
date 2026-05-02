import SwiftUI

/// ペース計算機の結果を画像化するための SwiftUI View。
/// 1080x1920 (Instagram Story / iPhone 縦長) を想定して固定幅で組む。
/// Web 版 marathon-record-app の `ShareCard.tsx` の Portrait バージョン相当。
struct PaceShareCard: View {
    let raceType: PaceRaceType
    let distanceKm: Double
    let goalTimeSeconds: Int
    let pacePerKm: Int
    let laps: [PaceLapSegment]

    /// 画像の論理サイズ。`ImageRenderer` 側で scale を掛けて高解像度化する。
    static let portraitSize = CGSize(width: 540, height: 960)  // 1080x1920 を 0.5x

    var body: some View {
        ZStack(alignment: .top) {
            // 背景: 黒地 + 黄色アクセントのグラデーション縁取り
            Color.bgPrimary
            VStack(spacing: 0) {
                Color.accentPrimary.frame(height: 4)
                Spacer()
                Color.accentPrimary.frame(height: 4)
            }
            .opacity(0.8)

            VStack(spacing: 0) {
                header
                heroBlock
                Divider()
                    .overlay(.white.opacity(0.08))
                    .padding(.horizontal, 28)
                lapsBlock
                Spacer()
                footer
            }
            .padding(.top, 36)
            .padding(.bottom, 24)
        }
        .frame(width: Self.portraitSize.width, height: Self.portraitSize.height)
        .clipped()
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 4) {
            Text("RUN JOURNEY")
                .appText(.eyebrow)
                .foregroundStyle(.secondary)
            Text(raceType.labelLong)
                .appText(.displaySm)
                .foregroundStyle(Color.accentPrimary)
        }
        .padding(.bottom, 28)
    }

    // MARK: - Hero (large pace)

    private var heroBlock: some View {
        VStack(spacing: 12) {
            Text("AVERAGE PACE")
                .appText(.eyebrow)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(PaceUtils.formatPaceSimple(pacePerKm))
                    .appText(.codeHero)
                    .foregroundStyle(Color.accentPrimary)
                Text("/ km")
                    .appText(.bodyLg)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 12)
            }

            HStack(spacing: 20) {
                metricColumn(
                    label: "DISTANCE",
                    value: String(format: "%.2f", distanceKm),
                    suffix: "km"
                )
                Divider().frame(height: 36).overlay(.white.opacity(0.15))
                metricColumn(
                    label: "GOAL TIME",
                    value: PaceUtils.formatTimeSimple(goalTimeSeconds),
                    suffix: nil
                )
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 28)
    }

    private func metricColumn(label: String, value: String, suffix: String?) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .appText(.eyebrow)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .appText(.codeMd)
                    .foregroundStyle(Color.textPrimary)
                if let suffix {
                    Text(suffix)
                        .appText(.bodySm)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Laps

    private var lapsBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SPLITS")
                .appText(.eyebrow)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 4)

            // 最大 12 行に絞って画像内に収める。多い時は等間隔で間引く。
            let displayed = downsample(laps, max: 12)
            ForEach(displayed) { lap in
                let isMilestone = lap.distanceLabel == "GOAL" || lap.distanceLabel == "HALF"
                HStack {
                    Text(lap.distanceLabel)
                        .appText(isMilestone ? .codeXsBold : .codeXs)
                        .foregroundStyle(lapColor(lap))
                        .frame(width: 60, alignment: .leading)
                    Spacer()
                    Text(PaceUtils.formatTimeSimple(Int(lap.cumulativeTime)))
                        .appText(.codeSmBold)
                        .foregroundStyle(Color.textPrimary)
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 22)
    }

    private func lapColor(_ lap: PaceLapSegment) -> Color {
        switch lap.distanceLabel {
        case "GOAL": return Color.accentPrimary
        case "HALF": return .orange
        default: return .secondary
        }
    }

    /// 指定数を超える場合は均等間隔でサンプリングする。
    /// 最初・HALF・GOAL は必ず残す。
    private func downsample(_ all: [PaceLapSegment], max: Int) -> [PaceLapSegment] {
        guard all.count > max else { return all }
        var indices: Set<Int> = [0, all.count - 1]
        // HALF/GOAL は必須
        for (i, lap) in all.enumerated() where lap.distanceLabel == "HALF" || lap.distanceLabel == "GOAL" {
            indices.insert(i)
        }
        let stride = Double(all.count) / Double(max - indices.count)
        var i: Double = 0
        while indices.count < max {
            indices.insert(Int(i.rounded()))
            i += stride
        }
        return indices.sorted().compactMap { idx in
            guard idx >= 0 && idx < all.count else { return nil }
            return all[idx]
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 4) {
            Text("Generated with RunJourney iOS")
                .appText(.bodyXs)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 28)
    }
}

#Preview {
    PaceShareCard(
        raceType: .full,
        distanceKm: 42.195,
        goalTimeSeconds: 4 * 3600,
        pacePerKm: 341,
        laps: PaceUtils.generateLaps(
            config: PaceConstants.configs[.full]!,
            goalTimeSeconds: 4 * 3600
        )
    )
}
