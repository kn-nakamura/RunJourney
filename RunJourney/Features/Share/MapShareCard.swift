import SwiftUI
import CoreLocation

/// マップ画面 (= ピン散布図) を共有用画像にレンダリングする SwiftUI View。
///
/// ピン背景には実際の地図タイルではなく、`SharePinField` で簡易メルカトル投影した
/// アクセント色のドットを並べる。これは:
/// - Mapbox / Apple Maps の利用規約上、サードパーティ画像書き出しに制限があるため
/// - レンダリングをアプリ内のアセットだけで完結させたいため
struct MapShareCard: View {
    let races: [Race]
    /// 実フィルタ後のレース数 (例: カテゴリ絞込中なら表示中件数)。races.count と
    /// 一致する場合は単に「Races」と表示する。
    let totalCount: Int
    /// 1 件選択中シェア用のメインレース (任意)。指定時はそのレース名がヒーローになる。
    let highlight: Race?
    let unit: DistanceUnit
    let config: ShareStyleConfig

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
        // (0,0) のレースは除外。座標未確定なので地図にも出していない。
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
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(palette.bgTertiary.opacity(0.6))
            SharePinField(pins: pins, palette: palette, accent: accentColor)
                .padding(8)
        }
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
            // Race highlighted: show category + location subtitle.
            let parts = [highlight?.category.displayName, highlight?.city, highlight?.country]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
            return parts.joined(separator: " · ")
        }
        // All races mode: show counts + categories.
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
        // 合計距離 (PB / 結果がある race のみ加算するわけではなく、各 race の distance)
        let totalKm = races.reduce(0.0) { $0 + ($1.distanceKm ?? $1.category.defaultDistanceKm ?? 0) }
        let countries = Set(races.compactMap { $0.country.isEmpty ? nil : $0.country }).count

        HStack(spacing: 12) {
            statTile(
                label: "RACES",
                value: "\(races.count)",
                unit: nil
            )
            statTile(
                label: "DISTANCE",
                value: PaceUtils.formatDistanceValue(km: totalKm, in: unit),
                unit: unit.label
            )
            statTile(
                label: "COUNTRIES",
                value: "\(countries)",
                unit: nil
            )
        }
    }

    @ViewBuilder
    private func statTile(label: String, value: String, unit: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .appText(.eyebrow)
                .foregroundStyle(palette.textMuted)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .appText(.codeMdBold)
                    .foregroundStyle(palette.textPrimary)
                if let u = unit {
                    Text(u)
                        .appText(.bodyXs)
                        .foregroundStyle(palette.textMuted)
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
            Text(heroTitle)
                .appText(.displayLg)
                .foregroundStyle(palette.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
            Text(heroSubtitle)
                .appText(.bodySm)
                .foregroundStyle(palette.textMuted)
                .lineLimit(1)
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
/// SwiftUI 標準の `FlowLayout` (iOS 16+ Layout) を使えば短く書けるが、
/// プロジェクト全体で iOS 17 を最低想定としつつ、テキストフォールバック挙動を
/// 安定させるため自前で持つ。
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
