import SwiftUI

/// ペース計算機の結果を画像化するための SwiftUI View。
///
/// 旧実装は 1080×1920 (Story) 固定だったが、新シェアキット (`ShareStyleConfig`) に
/// 揃えて Portrait / Square / Landscape / Wide の 4 サイズと、Dark/Light テーマ +
/// アクセント色変更に対応する。
struct PaceShareCard: View {
    let raceType: PaceRaceType
    let distanceKm: Double
    let goalTimeSeconds: Int
    let pacePerKm: Int
    let laps: [PaceLapSegment]
    let unit: DistanceUnit
    let config: ShareStyleConfig

    private var palette: SharePalette { config.theme.palette }
    private var accentColor: Color { Color(hex: config.accent.hex) }

    /// 後方互換用の固定サイズ (旧 PaceShareSheet が参照していたサイズ)。
    /// 新コードでは `config.format.logicalSize` を使う。
    static let portraitSize = ShareFormat.portrait.logicalSize

    var body: some View {
        ZStack {
            ShareCardKit.background(palette: palette, accent: accentColor, format: config.format)

            switch config.format {
            case .portrait:
                portraitLayout
            case .square:
                squareLayout
            case .landscape, .wide:
                horizontalLayout
            }
        }
        .frame(width: config.format.logicalSize.width,
               height: config.format.logicalSize.height)
        .clipped()
    }

    // MARK: - Hero / shared

    private var header: some View {
        VStack(spacing: 6) {
            ShareCardKit.watermark(palette: palette, accent: accentColor)
            Text(raceType.labelLong)
                .appText(.displayMd)
                .foregroundStyle(accentColor)
        }
    }

    @ViewBuilder
    private var heroBlock: some View {
        VStack(spacing: 8) {
            Text("AVERAGE PACE")
                .appText(.eyebrow)
                .foregroundStyle(palette.textMuted)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(PaceUtils.formatPaceSimple(PaceUtils.paceSecondsPerUnit(secPerKm: pacePerKm, in: unit)))
                    .appText(.codeXl)
                    .foregroundStyle(accentColor)
                Text("/ \(unit.label)")
                    .appText(.bodyBaseBold)
                    .foregroundStyle(palette.textMuted)
                    .padding(.bottom, 6)
            }
            HStack(spacing: 18) {
                metricColumn(
                    label: "DISTANCE",
                    value: PaceUtils.formatDistanceValue(km: distanceKm, in: unit),
                    suffix: unit.label
                )
                Divider().frame(height: 32).overlay(palette.border)
                metricColumn(
                    label: "GOAL TIME",
                    value: PaceUtils.formatTimeSimple(goalTimeSeconds),
                    suffix: nil
                )
            }
        }
    }

    private func metricColumn(label: String, value: String, suffix: String?) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .appText(.eyebrow)
                .foregroundStyle(palette.textMuted)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .appText(.codeLg)
                    .foregroundStyle(palette.textPrimary)
                if let suffix {
                    Text(suffix)
                        .appText(.bodyBaseBold)
                        .foregroundStyle(palette.textMuted)
                }
            }
        }
    }

    // MARK: - Splits

    @ViewBuilder
    private func splitsBlock(maxRows: Int) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("SPLITS")
                .appText(.eyebrow)
                .foregroundStyle(palette.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 4)
            let displayed = downsample(laps, max: maxRows)
            ForEach(displayed) { lap in
                lapRow(lap)
            }
        }
    }

    private func lapRow(_ lap: PaceLapSegment) -> some View {
        let isMilestone = lap.distanceLabel == "GOAL" || lap.distanceLabel == "HALF"
        let ratio = PaceUtils.paceBarRatio(pace: lap.pacePerKm, basePace: pacePerKm)
        let barColor = PaceUtils.paceBarColor(pace: lap.pacePerKm, basePace: pacePerKm)
        return ZStack(alignment: .leading) {
            GeometryReader { geo in
                LinearGradient(
                    gradient: Gradient(colors: [
                        barColor.opacity(0.55),
                        barColor.opacity(0.10)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: max(2, geo.size.width * ratio), height: geo.size.height)
            }
            .allowsHitTesting(false)

            HStack(spacing: 8) {
                Text(lapDistanceLabel(lap))
                    .appText(isMilestone ? .codeMdBold : .codeMd)
                    .foregroundStyle(lapColor(lap))
                    .frame(width: 78, alignment: .leading)
                Text(PaceUtils.formatPaceSimple(PaceUtils.paceSecondsPerUnit(secPerKm: lap.pacePerKm, in: unit)))
                    .appText(.codeMdBold)
                    .foregroundStyle(accentColor)
                Spacer()
                Text(PaceUtils.formatTimeSimple(Int(lap.cumulativeTime)))
                    .appText(.codeLgBold)
                    .foregroundStyle(palette.textPrimary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .frame(minHeight: 42)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func lapColor(_ lap: PaceLapSegment) -> Color {
        switch lap.distanceLabel {
        case "GOAL": return accentColor
        case "HALF": return Color(hex: 0xF7A23B)
        default: return palette.textPrimary.opacity(0.85)
        }
    }

    private func lapDistanceLabel(_ lap: PaceLapSegment) -> String {
        if lap.distanceLabel == "HALF" || lap.distanceLabel == "GOAL" {
            return lap.distanceLabel
        }
        let kmValue = Double(lap.distanceLabel) ?? lap.endKm
        return "\(PaceUtils.formatDistanceValue(km: kmValue, in: unit)) \(unit.label)"
    }

    /// 指定数を超える場合は均等間隔でサンプリングする。最初・HALF・GOAL は必ず残す。
    private func downsample(_ all: [PaceLapSegment], max: Int) -> [PaceLapSegment] {
        guard all.count > max else { return all }
        var indices: Set<Int> = [0, all.count - 1]
        for (i, lap) in all.enumerated() where lap.distanceLabel == "HALF" || lap.distanceLabel == "GOAL" {
            indices.insert(i)
        }
        let stride = Double(all.count) / Double(Swift.max(1, max - indices.count))
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

    // MARK: - Layouts

    private var portraitLayout: some View {
        VStack(spacing: 0) {
            header.padding(.top, 28)
            heroBlock.padding(.vertical, 18)
            Divider().overlay(palette.border).padding(.horizontal, 26)
            splitsBlock(maxRows: 11)
                .padding(.horizontal, 22)
                .padding(.top, 14)
            Spacer(minLength: 8)
            footer.padding(.bottom, 14)
        }
    }

    private var squareLayout: some View {
        VStack(spacing: 8) {
            header.padding(.top, 14)
            heroBlock
            splitsBlock(maxRows: 7)
                .padding(.horizontal, 22)
            Spacer(minLength: 4)
            footer.padding(.bottom, 12)
        }
    }

    private var horizontalLayout: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                header.frame(maxWidth: .infinity, alignment: .leading)
                heroBlock.frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
                footer
            }
            .padding(.leading, 26)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading) {
                splitsBlock(maxRows: 6)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 18)
            .padding(.trailing, 22)
            .frame(maxWidth: .infinity)
        }
    }

    private var footer: some View {
        Text("RUN JOURNEY · iOS")
            .appText(.eyebrow)
            .foregroundStyle(palette.textMuted.opacity(0.65))
            .frame(maxWidth: .infinity, alignment: .center)
    }
}
