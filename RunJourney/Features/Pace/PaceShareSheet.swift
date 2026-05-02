import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// `PaceShareCard` を ImageRenderer で UIImage に焼き、ShareLink で共有するためのシート。
/// macOS では NSImage 経由で書き出す。
struct PaceShareSheet: View {
    let raceType: PaceRaceType
    let distanceKm: Double
    let goalTimeSeconds: Int
    let pacePerKm: Int
    let laps: [PaceLapSegment]

    @Environment(\.dismiss) private var dismiss

    private var card: PaceShareCard {
        PaceShareCard(
            raceType: raceType,
            distanceKm: distanceKm,
            goalTimeSeconds: goalTimeSeconds,
            pacePerKm: pacePerKm,
            laps: laps
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // プレビュー
                    card
                        .scaleEffect(0.5)
                        .frame(width: PaceShareCard.portraitSize.width * 0.5,
                               height: PaceShareCard.portraitSize.height * 0.5)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.4), radius: 12, y: 4)

                    Text("Generate a 1080×1920 portrait image for Instagram Story / X")
                        .appText(.bodyXs)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

#if os(iOS)
                    if let image = renderImage() {
                        ShareLink(item: Image(uiImage: image), preview: SharePreview("Pace Plan", image: Image(uiImage: image))) {
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
                        .padding(.horizontal, 16)
                    } else {
                        Text("Failed to render image")
                            .appText(.bodySm)
                            .foregroundStyle(.red)
                    }
#else
                    Text("Image export is iOS only")
                        .appText(.bodySm)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 24)
#endif
                }
                .padding(.vertical, 16)
            }
            .background(Color.bgPrimary)
            .navigationTitle("SHARE")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

#if os(iOS)
    /// `ImageRenderer` で 1080x1920 PNG を生成。
    @MainActor
    private func renderImage() -> UIImage? {
        let renderer = ImageRenderer(content: card)
        // 540x960 の論理サイズに対して scale 2 で 1080x1920 px の解像度を得る
        renderer.scale = 2
        renderer.proposedSize = ProposedViewSize(PaceShareCard.portraitSize)
        return renderer.uiImage
    }
#endif
}
