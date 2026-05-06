import SwiftUI
import CoreLocation

// MARK: - ResultMetric

enum ResultMetric: String, CaseIterable, Identifiable {
    case avgPace, distance, avgHR, ascent, cadence, temp, place
    var id: String { rawValue }
    var label: String {
        switch self {
        case .avgPace:  return "AVG PACE"
        case .distance: return "DISTANCE"
        case .avgHR:    return "AVG HR"
        case .ascent:   return "ASCENT"
        case .cadence:  return "CADENCE"
        case .temp:     return "TEMP"
        case .place:    return "PLACE"
        }
    }
}

// MARK: - ResultShareCard

/// 1 件の `RaceResult` を共有用画像にレンダリングする SwiftUI View。
/// `ShareStyleConfig` (theme / accent / format) に従ってサイズ・配色を切替える。
struct ResultShareCard: View {
    let result: RaceResult
    let race: Race?
    let unit: DistanceUnit
    let config: ShareStyleConfig
    /// ルート (TrackPoint) を描画するか。座標が 2 点未満なら自動的に false 扱い。
    let showRoute: Bool
    /// 表示するメトリクスの集合。nil の場合はすべて表示 (後方互換)。
    let enabledMetrics: Set<ResultMetric>?

    init(
        result: RaceResult,
        race: Race?,
        unit: DistanceUnit,
        config: ShareStyleConfig,
        showRoute: Bool,
        enabledMetrics: Set<ResultMetric>? = nil
    ) {
        self.result = result
        self.race = race
        self.unit = unit
        self.config = config
        self.showRoute = showRoute
        self.enabledMetrics = enabledMetrics
    }

    private var palette: SharePalette { config.theme.palette }
    private var accentColor: Color { Color(hex: config.accent.hex) }

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

    // MARK: - Header / shared blocks

    private var categoryBadge: some View {
        let categoryText = race?.category.displayName ?? "Race"
        return Text(categoryText)
            .appText(.eyebrow)
            .foregroundStyle(accentColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                accentColor.opacity(0.16),
                in: Capsule()
            )
    }

    @ViewBuilder
    private func badges() -> some View {
        HStack(spacing: 6) {
            categoryBadge
            if result.isPB {
                pillBadge(text: "PB", fill: accentColor.opacity(0.22), fg: accentColor)
            }
            if result.isSB {
                pillBadge(text: "SB", fill: Color(hex: 0xC0C0C0).opacity(0.22), fg: Color(hex: 0xC0C0C0))
            }
        }
    }

    private func pillBadge(text: String, fill: Color, fg: Color) -> some View {
        Text(text)
            .appText(.badgeNumeric)
            .foregroundStyle(fg)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(fill, in: Capsule())
    }

    private var raceNameText: some View {
        Text((race?.name).flatMap { $0.isEmpty ? nil : $0 } ?? "Race")
            .appText(.displayLg)
            .foregroundStyle(palette.textPrimary)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.5)
    }

    private var metaText: some View {
        let parts = metaParts()
        return Text(parts.joined(separator: "  ·  "))
            .appText(.bodySm)
            .foregroundStyle(palette.textMuted)
            .multilineTextAlignment(.center)
            .lineLimit(1)
    }

    private func metaParts() -> [String] {
        var arr: [String] = []
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        arr.append(formatter.string(from: result.raceDate))
        if let city = race?.city, !city.isEmpty { arr.append(city) }
        if let country = race?.country, !country.isEmpty, country != "Japan" {
            arr.append(country)
        }
        return arr
    }

    private var heroTime: some View {
        Group {
            if let sec = result.finishTimeSec, sec > 0 {
                Text(formatTime(sec))
                    .appText(.codeXl)
                    .foregroundStyle(accentColor)
            } else {
                Text(result.isDNF ? "DNF" : "DNS")
                    .appText(.displayXl)
                    .foregroundStyle(palette.textMuted)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.4)
    }

    // MARK: - Stat tile

    private struct Stat: Identifiable, Hashable {
        let id = UUID()
        let label: String
        let value: String
        let unit: String?
    }

    private func isEnabled(_ metric: ResultMetric) -> Bool {
        enabledMetrics?.contains(metric) ?? true
    }

    private func makeStats(max: Int) -> [Stat] {
        var arr: [Stat] = []
        let s = result.summary
        if isEnabled(.avgPace), let pace = s?.avgPaceSecPerKm, pace > 0 {
            let displayed = PaceUtils.paceSecondsPerUnit(secPerKm: Int(pace.rounded()), in: unit)
            let m = displayed / 60
            let sec = displayed % 60
            arr.append(Stat(label: "AVG PACE", value: String(format: "%d:%02d", m, sec), unit: unit.perLabel))
        }
        if isEnabled(.distance), let dist = s?.totalDistanceM, dist > 0 {
            arr.append(Stat(label: "DISTANCE", value: PaceUtils.formatDistanceValue(km: dist / 1000, in: unit), unit: unit.label))
        }
        if isEnabled(.avgHR), let hr = s?.avgHeartRate {
            arr.append(Stat(label: "AVG HR", value: "\(hr)", unit: "bpm"))
        }
        if isEnabled(.ascent), let elev = s?.elevationGainM, elev > 0 {
            arr.append(Stat(label: "ASCENT", value: String(format: "%.0f", elev), unit: "m"))
        }
        if isEnabled(.cadence), let cad = s?.avgCadence {
            arr.append(Stat(label: "CADENCE", value: "\(cad)", unit: "spm"))
        }
        if isEnabled(.temp), let temp = result.weatherTempC ?? s?.avgTemperatureC {
            arr.append(Stat(label: "TEMP", value: String(format: "%.1f", temp), unit: "°C"))
        }
        if isEnabled(.place), let place = result.overallPlace {
            if let total = result.totalFinishers {
                arr.append(Stat(label: "PLACE", value: "\(place)/\(total)", unit: nil))
            } else {
                arr.append(Stat(label: "PLACE", value: "\(place)", unit: nil))
            }
        }
        return Array(arr.prefix(max))
    }

    @ViewBuilder
    private func statTile(_ s: Stat, compact: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(s.label)
                .appText(.eyebrow)
                .foregroundStyle(palette.textMuted)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(s.value)
                    .appText(compact ? .codeSmBold : .codeMdBold)
                    .foregroundStyle(palette.textPrimary)
                if let u = s.unit {
                    Text(u)
                        .appText(.bodyXs)
                        .foregroundStyle(palette.textMuted)
                }
            }
        }
        .padding(compact ? 8 : 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.bgTertiary, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Route

    private var routeCoords: [CLLocationCoordinate2D] {
        result.trackPoints.map(\.coordinate)
    }
    private var hasRoute: Bool { showRoute && routeCoords.count >= 2 }

    @ViewBuilder
    private func routeView(glow: Bool = true) -> some View {
        ShareRoutePath(
            coords: routeCoords,
            accent: accentColor,
            palette: palette,
            glow: glow && config.theme == .dark
        )
    }

    // MARK: - Layouts

    private var portraitLayout: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                ShareCardKit.watermark(palette: palette, accent: accentColor)
                badges()
            }
            .padding(.top, 28)

            Spacer(minLength: 12)

            VStack(spacing: 10) {
                raceNameText
                    .padding(.horizontal, 28)
                metaText
                    .padding(.horizontal, 28)
            }

            Spacer(minLength: 10)

            heroTime
                .padding(.horizontal, 24)

            Spacer(minLength: 10)

            VStack(spacing: 8) {
                let stats = makeStats(max: 4)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                          spacing: 8) {
                    ForEach(stats) { statTile($0) }
                }
            }
            .padding(.horizontal, 22)

            if hasRoute {
                routeView()
                    .padding(.top, 14)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 18)
                    .frame(maxHeight: .infinity)
            } else {
                Spacer(minLength: 18)
            }

            footer
                .padding(.bottom, 14)
        }
    }

    private var squareLayout: some View {
        VStack(spacing: 10) {
            HStack {
                ShareCardKit.watermark(palette: palette, accent: accentColor)
                Spacer()
                badges()
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)

            VStack(spacing: 6) {
                raceNameText.padding(.horizontal, 22)
                metaText.padding(.horizontal, 22)
            }

            heroTime
                .padding(.vertical, 4)

            if hasRoute {
                let stats = makeStats(max: 3)
                HStack(spacing: 8) {
                    ForEach(stats) { statTile($0, compact: true) }
                }
                .padding(.horizontal, 18)

                routeView()
                    .padding(.horizontal, 18)
                    .padding(.bottom, 14)
                    .frame(maxHeight: .infinity)
            } else {
                let stats = makeStats(max: 4)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                          spacing: 8) {
                    ForEach(stats) { statTile($0, compact: true) }
                }
                .padding(.horizontal, 18)
                Spacer(minLength: 6)
            }

            footer.padding(.bottom, 12)
        }
    }

    private var horizontalLayout: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                ShareCardKit.watermark(palette: palette, accent: accentColor)
                badges()
                Text((race?.name).flatMap { $0.isEmpty ? nil : $0 } ?? "Race")
                    .appText(.displayMd)
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                Text(metaParts().joined(separator: "  ·  "))
                    .appText(.bodySm)
                    .foregroundStyle(palette.textMuted)
                    .lineLimit(1)
                heroTime
                let stats = makeStats(max: hasRoute ? 2 : 4)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                          spacing: 8) {
                    ForEach(stats) { statTile($0, compact: true) }
                }
                Spacer(minLength: 0)
                footer
            }
            .padding(.leading, 28)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity, alignment: .leading)

            if hasRoute {
                routeView()
                    .padding(.vertical, 22)
                    .padding(.trailing, 22)
                    .frame(maxWidth: .infinity)
            } else {
                heroPlaceholder
                    .padding(.vertical, 22)
                    .padding(.trailing, 22)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private var heroPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(palette.bgTertiary)
            VStack(spacing: 6) {
                Image(systemName: race?.category.symbolName ?? "figure.run")
                    .font(.system(size: 56, weight: .regular))
                    .foregroundStyle(accentColor)
                Text(race?.category.displayName ?? "Race")
                    .appText(.eyebrow)
                    .foregroundStyle(palette.textMuted)
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        Text("RUN JOURNEY · iOS")
            .appText(.eyebrow)
            .foregroundStyle(palette.textMuted.opacity(0.65))
            .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Helpers

    private func formatTime(_ totalSec: Double) -> String {
        let s = Int(totalSec)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }
}
