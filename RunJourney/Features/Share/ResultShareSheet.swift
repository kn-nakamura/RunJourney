import SwiftUI
import CoreLocation
import MapKit
#if canImport(UIKit)
import UIKit
#endif

/// `RaceResult` を `ResultShareCard` 経由で画像化して共有 / 保存するシート。
struct ResultShareSheet: View {
    let result: RaceResult
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var systemColorScheme
    @AppStorage("distanceUnit") private var distanceUnitRaw: String = DistanceUnit.km.rawValue

    @State private var config: ShareStyleConfig
    @State private var appDefaults: ShareStyleConfig
    @State private var showRoute: Bool
    @State private var showMap: Bool
    @State private var hasResolvedDefaults = false
    @State private var enabledMetrics: Set<ResultMetric> = Set(ResultMetric.allCases)
    @State private var mapComposite: Image? = nil
    @State private var isLoadingMap = false
    /// 合成済みアクセントの hex 値。アクセント変更時に再合成するためのキャッシュキー。
    @State private var mapCompositeAccent: UInt32? = nil
    /// 合成済みテーマ。テーマ切替時に地図タイルを再合成するためのキャッシュキー。
    @State private var mapCompositeTheme: ShareTheme? = nil

    init(result: RaceResult) {
        self.result = result
        let placeholder = ShareStyleConfig.defaultsFromAppSettings(systemColorScheme: .dark)
        _config = State(initialValue: placeholder)
        _appDefaults = State(initialValue: placeholder)
        _showRoute = State(initialValue: !result.trackPoints.isEmpty)
        _showMap = State(initialValue: !result.trackPoints.isEmpty)
    }

    private var unit: DistanceUnit { DistanceUnit.resolve(distanceUnitRaw) }
    private var hasRoute: Bool { result.trackPoints.count >= 2 }

    private var card: ResultShareCard {
        ResultShareCard(
            result: result,
            race: result.race,
            unit: unit,
            config: config,
            showRoute: showRoute && hasRoute,
            enabledMetrics: enabledMetrics,
            mapComposite: (showRoute && showMap) ? mapComposite : nil
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    preview
                    if hasRoute {
                        routeToggle
                        mapToggle
                    }
                    metricsSection
                    ShareStyleEditor(config: $config, appDefaults: appDefaults)
                    shareButton
                }
                .padding(16)
            }
            .background(Color.bgPrimary)
            .navigationTitle("SHARE RESULT")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onAppear {
            guard !hasResolvedDefaults else { return }
            hasResolvedDefaults = true
            let resolved = ShareStyleConfig.defaultsFromAppSettings(systemColorScheme: systemColorScheme)
            appDefaults = resolved
            config = resolved
        }
        .task(id: ShareMapCacheKey(theme: config.theme, accent: config.accent.hex)) {
            // アクセント色 / テーマ変更時に地図タイルとルート色を反映するため再合成する。
            await loadMapCompositeIfNeeded()
        }
    }

    // MARK: - Preview

    private var preview: some View {
        let logical = config.format.logicalSize
        let maxPreviewW: CGFloat = 360
        let scale = min(maxPreviewW / logical.width, 1.0)
        return VStack(spacing: 6) {
            ZStack {
                card
                    .scaleEffect(scale, anchor: .center)
                    .frame(width: logical.width * scale, height: logical.height * scale)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
                if isLoadingMap && showRoute && showMap {
                    ProgressView()
                        .tint(Color.accentPrimary)
                }
            }
            Text("\(Int(config.format.pixelSize.width)) × \(Int(config.format.pixelSize.height)) px")
                .appText(.bodyXs)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Route toggle

    private var routeToggle: some View {
        Toggle(isOn: $showRoute) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Show Route")
                    .appText(.bodySmBold)
                    .foregroundStyle(Color.textPrimary)
                Text("Plot the GPS track on the card")
                    .appText(.bodyXs)
                    .foregroundStyle(.secondary)
            }
        }
        .tint(Color.accentPrimary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Map toggle

    private var mapToggle: some View {
        Toggle(isOn: $showMap) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Show Map")
                    .appText(.bodySmBold)
                    .foregroundStyle(Color.textPrimary)
                Text("Render the actual map under the route")
                    .appText(.bodyXs)
                    .foregroundStyle(.secondary)
            }
        }
        .tint(Color.accentPrimary)
        .disabled(!showRoute)
        .opacity(showRoute ? 1.0 : 0.5)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Metrics section

    private var availableMetrics: [ResultMetric] {
        let s = result.summary
        return ResultMetric.allCases.filter { metric in
            switch metric {
            case .avgPace:  return (s?.avgPaceSecPerKm ?? 0) > 0
            case .distance: return (s?.totalDistanceM ?? 0) > 0
            case .avgHR:    return s?.avgHeartRate != nil
            case .ascent:   return (s?.elevationGainM ?? 0) > 0
            case .cadence:  return s?.avgCadence != nil
            case .temp:     return result.weatherTempC != nil || s?.avgTemperatureC != nil
            case .place:    return result.overallPlace != nil
            }
        }
    }

    @ViewBuilder
    private var metricsSection: some View {
        let metrics = availableMetrics
        if !metrics.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("METRICS")
                    .appText(.eyebrow)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.top, 14)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2),
                    spacing: 8
                ) {
                    ForEach(metrics) { metric in
                        metricPill(metric)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
            .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private func metricPill(_ metric: ResultMetric) -> some View {
        let selected = enabledMetrics.contains(metric)
        return Button {
            if selected {
                enabledMetrics.remove(metric)
            } else {
                enabledMetrics.insert(metric)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(selected ? Color.accentPrimary : Color.textPrimary.opacity(0.4))
                Text(metric.label)
                    .appText(.bodySmBold)
                    .foregroundStyle(Color.textPrimary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                selected ? Color.accentPrimary.opacity(0.14) : Color.bgTertiary,
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(selected ? Color.accentPrimary : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Share

    private var shareButton: some View {
#if os(iOS)
        Group {
            if let image = renderImage() {
                ShareLink(
                    item: Image(uiImage: image),
                    preview: SharePreview(result.race?.name ?? "Race Result",
                                          image: Image(uiImage: image))
                ) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share / Save to Photos")
                            .appText(.bodyBaseBold)
                    }
                    .foregroundStyle(Color.bgPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentPrimary, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            } else {
                Text("Failed to render image")
                    .appText(.bodySm)
                    .foregroundStyle(.red)
            }
        }
#else
        Text("Image export is iOS only")
            .appText(.bodySm)
            .foregroundStyle(.secondary)
#endif
    }

#if os(iOS)
    @MainActor
    private func renderImage() -> UIImage? {
        let renderer = ImageRenderer(content: card)
        renderer.scale = 2
        renderer.proposedSize = ProposedViewSize(config.format.logicalSize)
        return renderer.uiImage
    }
#endif

    // MARK: - Map snapshot

#if canImport(UIKit)
    /// 既に同じテーマ + アクセントで合成済みなら再フェッチしない。
    private func loadMapCompositeIfNeeded() async {
        guard hasRoute else { return }
        if mapCompositeAccent == config.accent.hex,
           mapCompositeTheme == config.theme,
           mapComposite != nil { return }
        await loadMapComposite()
    }

    private func loadMapComposite() async {
        let coords = result.trackPoints.map(\.coordinate)
        guard coords.count >= 2 else { return }

        await MainActor.run { isLoadingMap = true }
        defer { Task { @MainActor in isLoadingMap = false } }

        let lats = coords.map(\.latitude)
        let lngs = coords.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLng = lngs.min(), let maxLng = lngs.max() else { return }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )
        // ルートが矩形に収まるようにパディングを 30% 足す。極端に小さいスパンは下限で底上げ。
        let latSpan = max((maxLat - minLat) * 1.3, 0.005)
        let lngSpan = max((maxLng - minLng) * 1.3, 0.005)

        let opts = MKMapSnapshotter.Options()
        opts.region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latSpan, longitudeDelta: lngSpan)
        )
        opts.size = CGSize(width: 900, height: 900)
        opts.mapType = .mutedStandard
        opts.showsBuildings = false
        // テーマピッカーの値に応じて Light/Dark タイルを描き分ける。
        // 指定しないと呼び出し元 window の userInterfaceStyle が使われてしまい、
        // シート上でテーマを切り替えても地図がダークのまま残る。
        opts.traitCollection = UITraitCollection(traitsFrom: [
            UITraitCollection(userInterfaceStyle: config.theme == .dark ? .dark : .light),
            UITraitCollection(displayScale: 2)
        ])

        guard let snapshot = try? await MKMapSnapshotter(options: opts).start() else { return }

        let accentHex = config.accent.hex
        let accentUIColor = UIColor(hex: accentHex)
        let snapshotSize = snapshot.image.size

        let composite = UIGraphicsImageRenderer(size: snapshotSize).image { _ in
            snapshot.image.draw(at: .zero)

            // ルート折れ線。座標数が多い場合は SwiftUI 側と同じく最大 2000 点へ間引く。
            let path = UIBezierPath()
            let step = max(1, coords.count / 2000)
            var i = 0
            var first = true
            while i < coords.count {
                let p = snapshot.point(for: coords[i])
                if first { path.move(to: p); first = false } else { path.addLine(to: p) }
                i += step
            }
            let lastP = snapshot.point(for: coords[coords.count - 1])
            path.addLine(to: lastP)
            path.lineCapStyle = .round
            path.lineJoinStyle = .round

            // グロー (アクセント半透明・太め)
            accentUIColor.withAlphaComponent(0.45).setStroke()
            path.lineWidth = 14
            path.stroke()

            // 本線
            accentUIColor.setStroke()
            path.lineWidth = 7
            path.stroke()

            // 始点 (白丸)
            if let firstCoord = coords.first {
                let p = snapshot.point(for: firstCoord)
                let r: CGFloat = 11
                let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
                UIColor.white.setFill()
                UIBezierPath(ovalIn: rect).fill()
                let border = UIBezierPath(ovalIn: rect)
                border.lineWidth = 2.5
                UIColor.black.withAlphaComponent(0.35).setStroke()
                border.stroke()
            }
            // 終点 (アクセント丸)
            if let lastCoord = coords.last {
                let p = snapshot.point(for: lastCoord)
                let r: CGFloat = 11
                let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
                accentUIColor.setFill()
                UIBezierPath(ovalIn: rect).fill()
                let border = UIBezierPath(ovalIn: rect)
                border.lineWidth = 2.5
                UIColor.white.withAlphaComponent(0.8).setStroke()
                border.stroke()
            }
        }
        let snapshotTheme = config.theme
        await MainActor.run {
            mapComposite = Image(uiImage: composite)
            mapCompositeAccent = accentHex
            mapCompositeTheme = snapshotTheme
        }
    }
#else
    private func loadMapCompositeIfNeeded() async {}
#endif
}

/// `.task(id:)` 用の地図再合成キャッシュキー。
/// テーマとアクセントが両方一致するときだけ合成済み画像を使い回す。
private struct ShareMapCacheKey: Hashable {
    let theme: ShareTheme
    let accent: UInt32
}
