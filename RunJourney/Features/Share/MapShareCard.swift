import SwiftUI
import CoreLocation

// MARK: - MapMetric

enum MapMetric: String, CaseIterable, Identifiable {
    case races, distance, countries, cities
    var id: String { rawValue }
    var label: String {
        switch self {
        case .races:     return "RACES"
        case .distance:  return "DISTANCE"
        case .countries: return "COUNTRIES"
        case .cities:    return "CITIES"
        }
    }
}

// MARK: - MapShareCard

/// マップ画面 (= ピン散布図) を共有用画像にレンダリングする SwiftUI View。
///
/// mapComposite が渡された場合は MKMapSnapshotter の合成画像 (地図タイル + ピン) を使用。
/// 渡されない場合は `SharePinField` で簡易メルカトル投影したフォールバック表示にする。
struct MapShareCard: View {
    let races: [Race]
    /// 実フィルタ後のレース数 (例: カテゴリ絞込中なら表示中件数)。races.count と
    /// 一致する場合は単に「Races」と表示する。
    let totalCount: Int
    /// 1 件選択中シェア用のメインレース (任意)。指定時はそのレース名がヒーローになる。
    let highlight: Race?
    let unit: DistanceUnit
    let config: ShareStyleConfig
    /// MKMapSnapshotter で生成した合成画像 (地図 + ピン)。nil ならフォールバック描画。
    let mapComposite: Image?
    /// 表示するメトリクスの集合。
    let enabledMapMetrics: Set<MapMetric>

    init(
        races: [Race],
        totalCount: Int,
        highlight: Race? = nil,
        unit: DistanceUnit,
        config: ShareStyleConfig,
        mapComposite: Image? = nil,
        enabledMapMetrics: Set<MapMetric> = Set(MapMetric.allCases)
    ) {
        self.races = races
        self.totalCount = totalCount
        self.highlight = highlight
        self.unit = unit
        self.config = config
        self.mapComposite = mapComposite
        self.enabledMapMetrics = enabledMapMetrics
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

    // MARK: - Building blocks

    private var pins: [SharePinField.Pin] {
        races
            .filter { !($0.lat == 0 && $0.lng == 0) }
            .map { race in
                SharePinField.Pin(
                    coord: CLLocationCoordinate2D(latitude: race.lat, longitude: race.lng),
                    color: race.category.pinColor
                )
            }
    }

    @ViewBuilder
    private var pinFieldView: some View {
        // `.scaledToFill()` を直接 ZStack の子に置くと、Image のレイアウトサイズが
        // ナチュラルサイズ (900×900) を主張して親 VStack を押し広げる。
        // Color.clear の overlay に閉じ込めて、画像は描画専用にする。
        Color.clear
            .overlay(
                Group {
                    if let composite = mapComposite {
                        composite
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        SharePinField(pins: pins, palette: palette, accent: accentColor)
                            .padding(8)
                    }
                }
            )
            .background(palette.bgTertiary.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(palette.border, lineWidth: 1)
            )
    }

    private var heroTitle: String {
        if let h = highlight, !h.name.isEmpty { return h.name }
        return "JOURNEYS"
    }

    private var heroSubtitle: String {
        if highlight != nil {
            let parts = [highlight?.category.displayName, highlight?.city, highlight?.country]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
            return parts.joined(separator: " · ")
        }
        let categoryCount = Set(races.map(\.category)).count
        if races.count == totalCount {
            return "\(races.count) races · \(categoryCount) categories"
        }
        return "\(races.count) of \(totalCount) races · \(categoryCount) categories"
    }

    @ViewBuilder
    private var legend: some View {
        let usedCategories = Array(Set(races.map(\.category))).sorted { lhs, rhs in
            (RaceCategory.allCases.firstIndex(of: lhs) ?? 0) <
            (RaceCategory.allCases.firstIndex(of: rhs) ?? 0)
        }
        if !usedCategories.isEmpty {
            FlowingHStack(spacing: 8) {
                ForEach(usedCategories) { cat in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(cat.pinColor)
                            .frame(width: 8, height: 8)
                        Text(cat.displayName)
                            .appText(.bodyXs)
                            .foregroundStyle(palette.textPrimary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(palette.bgTertiary, in: Capsule())
                }
            }
        }
    }

    @ViewBuilder
    private var totalsBlock: some View {
        let totalKm = races.reduce(0.0) { $0 + ($1.distanceKm ?? $1.category.defaultDistanceKm ?? 0) }
        let countries = Set(races.compactMap { $0.country.isEmpty ? nil : $0.country }).count
        let cities = Set(races.compactMap { race -> String? in
            guard let city = race.city, !city.isEmpty else { return nil }
            return city
        }).count
        let visible = MapMetric.allCases.filter { enabledMapMetrics.contains($0) }

        if !visible.isEmpty {
            // Portrait / Square のカード幅 (540pt) では 4 タイルを 1 行 HStack に詰めると
            // 横方向にあふれて両端が切れるため、3 タイル以上は 2 列 LazyVGrid に折り返す。
            // 横長フォーマット (Landscape / Wide) は左サイドバー幅で 1 行に並ぶので HStack のまま。
            let useGrid = !config.format.isWide && visible.count >= 3
            if useGrid {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                    spacing: 8
                ) {
                    ForEach(visible) { metric in
                        tile(for: metric, totalKm: totalKm, countries: countries, cities: cities)
                    }
                }
            } else {
                HStack(spacing: 8) {
                    ForEach(visible) { metric in
                        tile(for: metric, totalKm: totalKm, countries: countries, cities: cities)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func tile(for metric: MapMetric, totalKm: Double, countries: Int, cities: Int) -> some View {
        switch metric {
        case .races:
            statTile(label: metric.label, value: "\(races.count)", unit: nil)
        case .distance:
            statTile(label: metric.label, value: PaceUtils.formatDistanceValue(km: totalKm, in: unit), unit: unit.label)
        case .countries:
            statTile(label: metric.label, value: "\(countries)", unit: nil)
        case .cities:
            statTile(label: metric.label, value: "\(cities)", unit: nil)
        }
    }

    @ViewBuilder
    private func statTile(label: String, value: String, unit: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .appText(.eyebrow)
                .foregroundStyle(palette.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .appText(.codeMdBold)
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                if let u = unit {
                    Text(u)
                        .appText(.bodyXs)
                        .foregroundStyle(palette.textMuted)
                        .lineLimit(1)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.bgTertiary, in: RoundedRectangle(cornerRadius: 10))
    }

    private var titleView: some View {
        VStack(alignment: .leading, spacing: 6) {
            ShareCardKit.watermark(palette: palette, accent: accentColor)
                .lineLimit(1)
            Text(heroTitle)
                .appText(.displayLg)
                .foregroundStyle(palette.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(heroSubtitle)
                .appText(.bodySm)
                .foregroundStyle(palette.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var footer: some View {
        Text("RUN JOURNEY · iOS")
            .appText(.eyebrow)
            .foregroundStyle(palette.textMuted.opacity(0.65))
            .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Layouts

    private var portraitLayout: some View {
        VStack(spacing: 14) {
            titleView
                .padding(.horizontal, 24)
                .padding(.top, 26)
                .frame(maxWidth: .infinity, alignment: .leading)

            pinFieldView
                .padding(.horizontal, 22)
                .frame(maxHeight: .infinity)

            legend
                .padding(.horizontal, 22)

            totalsBlock
                .padding(.horizontal, 22)

            footer.padding(.bottom, 16)
        }
    }

    private var squareLayout: some View {
        VStack(spacing: 12) {
            titleView
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .frame(maxWidth: .infinity, alignment: .leading)

            pinFieldView
                .padding(.horizontal, 18)
                .frame(maxHeight: .infinity)

            legend.padding(.horizontal, 22)
            totalsBlock.padding(.horizontal, 18)

            footer.padding(.bottom, 12)
        }
    }

    private var horizontalLayout: some View {
        HStack(spacing: 0) {
            // Left identity
            VStack(alignment: .leading, spacing: 14) {
                titleView
                Spacer(minLength: 0)
                legend
                totalsBlock
                footer
            }
            .padding(.leading, 28)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right pin field
            pinFieldView
                .padding(.vertical, 22)
                .padding(.trailing, 22)
                .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - FlowingHStack

/// 単一行に収まらないときに自動で折り返す簡易 HStack。
struct FlowingHStack<Content: View>: View {
    let spacing: CGFloat
    let content: () -> Content

    init(spacing: CGFloat = 8, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        FlowLayout(spacing: spacing) {
            content()
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var totalH: CGFloat = 0
        var rowH: CGFloat = 0
        var rowW: CGFloat = 0

        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if rowW + s.width > maxWidth, rowW > 0 {
                totalH += rowH + spacing
                rowW = 0
                rowH = 0
            }
            rowW += s.width + spacing
            rowH = max(rowH, s.height)
        }
        totalH += rowH
        let width = (proposal.width ?? rowW)
        return CGSize(width: width, height: totalH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowH: CGFloat = 0

        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowH + spacing
                rowH = 0
            }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: s.width, height: s.height))
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
    }
}
