import SwiftUI
import MapKit
#if canImport(UIKit)
import UIKit
#endif

/// マップ画面 (RaceMapView) から開く共有シート。
/// `mappableRaces` (= フィルタ適用後のレース集合) を `MapShareCard` で画像化する。
struct MapShareSheet: View {
    let races: [Race]
    let totalCount: Int
    let highlight: Race?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var systemColorScheme
    @AppStorage("distanceUnit") private var distanceUnitRaw: String = DistanceUnit.km.rawValue

    @State private var config: ShareStyleConfig
    @State private var appDefaults: ShareStyleConfig
    @State private var hasResolvedDefaults = false
    @State private var mapComposite: Image? = nil
    @State private var isLoadingMap = false
    @State private var enabledMapMetrics: Set<MapMetric> = Set(MapMetric.allCases)

    init(races: [Race], totalCount: Int? = nil, highlight: Race? = nil) {
        self.races = races
        self.totalCount = totalCount ?? races.count
        self.highlight = highlight
        let placeholder = ShareStyleConfig.defaultsFromAppSettings(systemColorScheme: .dark)
        _config = State(initialValue: placeholder)
        _appDefaults = State(initialValue: placeholder)
    }

    private var unit: DistanceUnit { DistanceUnit.resolve(distanceUnitRaw) }

    private var card: MapShareCard {
        MapShareCard(
            races: races,
            totalCount: totalCount,
            highlight: highlight,
            unit: unit,
            config: config,
            mapComposite: mapComposite,
            enabledMapMetrics: enabledMapMetrics
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    preview
                    metricsSection
                    ShareStyleEditor(config: $config, appDefaults: appDefaults)
                    shareButton
                }
                .padding(16)
            }
            .background(Color.bgPrimary)
            .navigationTitle("SHARE MAP")
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
        .task {
            await loadMapComposite()
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
                if isLoadingMap {
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

    // MARK: - Metrics section

    private var metricsSection: some View {
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
                ForEach(MapMetric.allCases) { metric in
                    metricPill(metric)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 14))
    }

    private func metricPill(_ metric: MapMetric) -> some View {
        let selected = enabledMapMetrics.contains(metric)
        return Button {
            if selected {
                enabledMapMetrics.remove(metric)
            } else {
                enabledMapMetrics.insert(metric)
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
                    preview: SharePreview("Run Journey Map", image: Image(uiImage: image))
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
    private func loadMapComposite() async {
        let mappable = races.filter { !($0.lat == 0 && $0.lng == 0) }
        guard !mappable.isEmpty else { return }

        await MainActor.run { isLoadingMap = true }
        defer { Task { @MainActor in isLoadingMap = false } }

        let lats = mappable.map(\.lat)
        let lngs = mappable.map(\.lng)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLng = lngs.min(), let maxLng = lngs.max() else { return }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )
        let latSpan = max(maxLat - minLat, 1.0) * 1.6
        let lngSpan = max(maxLng - minLng, 1.0) * 1.6

        let opts = MKMapSnapshotter.Options()
        opts.region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latSpan, longitudeDelta: lngSpan)
        )
        opts.size = CGSize(width: 900, height: 900)
        opts.mapType = .mutedStandard
        opts.showsBuildings = false

        guard let snapshot = try? await MKMapSnapshotter(options: opts).start() else { return }

        let snapshotSize = snapshot.image.size
        let composite = UIGraphicsImageRenderer(size: snapshotSize).image { _ in
            snapshot.image.draw(at: .zero)
            for race in mappable {
                let coord = CLLocationCoordinate2D(latitude: race.lat, longitude: race.lng)
                let pt = snapshot.point(for: coord)
                guard snapshotSize.contains(pt) else { continue }

                let pinColor = UIColor(race.category.pinColor)
                let radius: CGFloat = 9
                let r = CGRect(x: pt.x - radius, y: pt.y - radius,
                               width: radius * 2, height: radius * 2)
                pinColor.setFill()
                UIBezierPath(ovalIn: r).fill()

                let border = UIBezierPath(ovalIn: r.insetBy(dx: 1.5, dy: 1.5))
                UIColor.white.setStroke()
                border.lineWidth = 2.5
                border.stroke()
            }
        }
        await MainActor.run { mapComposite = Image(uiImage: composite) }
    }
#else
    private func loadMapComposite() async {}
#endif
}

private extension CGSize {
    func contains(_ point: CGPoint) -> Bool {
        point.x >= 0 && point.y >= 0 && point.x <= width && point.y <= height
    }
}
