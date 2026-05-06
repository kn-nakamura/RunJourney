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
    @State private var enabledMetrics: Set<ResultMetric> = Set(ResultMetric.allCases)

    init(result: RaceResult) {
        self.result = result
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
            showRoute: showRoute && hasRoute,
            enabledMetrics: enabledMetrics
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    preview
                    if hasRoute { routeToggle }
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
    }

    // MARK: - Preview

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
}
