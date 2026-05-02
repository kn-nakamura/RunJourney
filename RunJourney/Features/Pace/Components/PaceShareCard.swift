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

    @AppStorage("distanceUnit") private var distanceUnitRaw: String = DistanceUnit.km.rawValue
    private var unit: DistanceUnit { DistanceUnit.resolve(distanceUnitRaw) }

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
        VStack(spacing: 6) {
            Text("RUN JOURNEY")
                .appText(.eyebrow)
                .foregroundStyle(Color.textPrimary.opacity(0.78))
            Text(raceType.labelLong)
                .appText(.displayMd)
                .foregroundStyle(Color.accentPrimary)
        }
        .padding(.bottom, 24)
    }

    // MARK: - Hero (large pace)

    private var heroBlock: some View {
        VStack(spacing: 10) {
            Text("AVERAGE PACE")
                .appText(.eyebrow)
                .foregroundStyle(Color.textPrimary.opacity(0.78))
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(PaceUtils.formatPaceSimple(PaceUtils.paceSecondsPerUnit(secPerKm: pacePerKm, in: unit)))
                    .appText(.codeXl)
                    .foregroundStyle(Color.accentPrimary)
                Text("/ \(unit.label)")
                    .appText(.bodyBaseBold)
                    .foregroundStyle(Color.textPrimary.opacity(0.78))
                    .padding(.bottom, 8)
            }

            HStack(spacing: 24) {
                metricColumn(
                    label: "DISTANCE",
                    value: PaceUtils.formatDistanceValue(km: distanceKm, in: unit),
                    suffix: unit.label
                )
                Divider().frame(height: 36).overlay(.white.opacity(0.15))
                metricColumn(
                    label: "GOAL TIME",
                    value: PaceUtils.formatTimeSimple(goalTimeSeconds),
                    suffix: nil
                )
            }
            .padding(.top, 6)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 20)
    }

    private func metricColumn(label: String, value: String, suffix: String?) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .appText(.eyebrow)
                .foregroundStyle(Color.textPrimary.opacity(0.78))
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .appText(.codeLg)
                    .foregroundStyle(Color.textPrimary)
                if let suffix {
                    Text(suffix)
                        .appText(.bodyBaseBold)
                        .foregroundStyle(Color.textPrimary.opacity(0.78))
                }
            }
        }
    }

    // MARK: - Laps

    private var lapsBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SPLITS")
                .appText(.eyebrow)
                .foregroundStyle(Color.textPrimary.opacity(0.78))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 6)

            // 最大 11 行に絞って画像内に収める。多い時は等間隔で間引く。
            let displayed = downsample(laps, max: 11)
            ForEach(displayed) { lap in
                lapRow(lap)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 24)
    }

    /// SPLITS 1 行: 背景に basePace 基準のグラデーションバー、上にラベル/タイムを重ねる。
    private func lapRow(_ lap: PaceLapSegment) -> some View {
        let isMilestone = lap.distanceLabel == "GOAL" || lap.distanceLabel == "HALF"
        let ratio = PaceUtils.paceBarRatio(pace: lap.pacePerKm, basePace: pacePerKm)
        let color = PaceUtils.paceBarColor(pace: lap.pacePerKm, basePace: pacePerKm)

        return ZStack(alignment: .leading) {
            GeometryReader { geo in
                LinearGradient(
                    gradient: Gradient(colors: [
                        color.opacity(0.55),
                        color.opacity(0.10)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: max(2, geo.size.width * ratio), height: geo.size.height)
            }
            .allowsHitTesting(false)

            HStack(spacing: 10) {
                Text(lapDistanceLabel(lap))
                    .appText(isMilestone ? .codeMdBold : .codeMd)
                    .foregroundStyle(lapColor(lap))
                    .frame(width: 88, alignment: .leading)
                Text(PaceUtils.formatPaceSimple(PaceUtils.paceSecondsPerUnit(secPerKm: lap.pacePerKm, in: unit)))
                    .appText(.codeMdBold)
                    .foregroundStyle(Color.accentPrimary)
                Spacer()
                Text(PaceUtils.formatTimeSimple(Int(lap.cumulativeTime)))
                    .appText(.codeLgBold)
                    .foregroundStyle(Color.textPrimary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(minHeight: 50)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func lapColor(_ lap: PaceLapSegment) -> Color {
        switch lap.distanceLabel {
        case "GOAL": return Color.accentPrimary
        case "HALF": return .orange
        default: return Color.textPrimary.opacity(0.85)
        }
    }

    /// HALF / GOAL はそのまま、それ以外は km 数値ラベルを単位変換して表示。
    private func lapDistanceLabel(_ lap: PaceLapSegment) -> String {
        if lap.distanceLabel == "HALF" || lap.distanceLabel == "GOAL" {
            return lap.distanceLabel
        }
        let kmValue = Double(lap.distanceLabel) ?? lap.endKm
        return "\(PaceUtils.formatDistanceValue(km: kmValue, in: unit)) \(unit.label)"
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
                .foregroundStyle(Color.textPrimary.opacity(0.55))
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
