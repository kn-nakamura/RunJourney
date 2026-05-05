import SwiftUI
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
            config: config
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    preview
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
    }

    private var preview: some View {
        let logical = config.format.logicalSize
        let maxPreviewW: CGFloat = 360
        let scale = min(maxPreviewW / logical.width, 1.0)
        return VStack(spacing: 6) {
            card
                .scaleEffect(scale, anchor: .center)
                .frame(width: logical.width * scale, height: logical.height * scale)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
            Text("\(Int(config.format.pixelSize.width)) × \(Int(config.format.pixelSize.height)) px")
                .appText(.bodyXs)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

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
}
