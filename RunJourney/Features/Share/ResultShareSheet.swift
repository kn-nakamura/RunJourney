import SwiftUI
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
    @State private var hasResolvedDefaults = false

    init(result: RaceResult) {
        self.result = result
        // init() 時点では @Environment が読めないため一旦 dark を仮置き。
        // .onAppear で systemColorScheme を解決して上書きする。
        let placeholder = ShareStyleConfig.defaultsFromAppSettings(systemColorScheme: .dark)
        _config = State(initialValue: placeholder)
        _appDefaults = State(initialValue: placeholder)
        _showRoute = State(initialValue: !result.trackPoints.isEmpty)
    }

    private var unit: DistanceUnit { DistanceUnit.resolve(distanceUnitRaw) }
    private var hasRoute: Bool { result.trackPoints.count >= 2 }

    private var card: ResultShareCard {
        ResultShareCard(
            result: result,
            race: result.race,
            unit: unit,
            config: config,
            showRoute: showRoute && hasRoute
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    preview
                    if hasRoute { routeToggle }
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
    }

    // MARK: - Preview

    private var preview: some View {
        let logical = config.format.logicalSize
        // プレビュー幅にフィットするスケールを計算 (画面幅から左右 padding を除いた幅)。
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
}
