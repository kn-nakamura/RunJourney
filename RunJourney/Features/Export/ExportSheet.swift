import SwiftUI
#if canImport(UIKit)
import UIKit
import MapKit
#endif

/// 動画書き出しシート。プレビューやカメラ・スピードのスライダーは持たず、
/// 「出力オプション選択」と「進捗・完了・失敗」の表示だけを担う。
/// プレビューは再生画面そのものなので、このシートはコンパクトな
/// `.medium` detent で開いて再生ビューを背後に残す。
/// バックグラウンド書き出しは `RouteVideoRenderer.shared` が継続するため、
/// シートを閉じてもレンダリングは止まらない。
struct ExportSheet: View {
    @Bindable var controller: PlaybackController
    let raceName: String?
    let finishTimeSec: Double?
#if canImport(UIKit)
    let strokeColor: UIColor
    let configuration: MKMapConfiguration
    let userInterfaceStyle: UIUserInterfaceStyle
    /// 再生画面側で現在採用されているカメラ値 (override + auto fallback の結果)。
    let cameraOverride: FollowCameraOverride
    let playbackSpeed: Double
#endif

    @Environment(\.dismiss) private var dismiss

#if canImport(UIKit)
    @State private var renderer = RouteVideoRenderer.shared
    @State private var showShareSheet: Bool = false

    /// 解像度の選択を端末ごとに記憶する。
    @AppStorage("export.resolution") private var resolutionRaw: String = RouteVideoResolution.sd720.rawValue
    /// クオリティ (動画長 / アニメーションペース) の選択を記憶する。
    @AppStorage("export.quality") private var qualityRaw: String = ExportQuality.standard.rawValue

    private var resolution: RouteVideoResolution {
        RouteVideoResolution(rawValue: resolutionRaw) ?? .sd720
    }
    private var quality: ExportQuality {
        ExportQuality(rawValue: qualityRaw) ?? .standard
    }
#endif

    var body: some View {
        NavigationStack {
#if canImport(UIKit)
            content
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
#else
            unsupportedContent
#endif
        }
    }

#if canImport(UIKit)
    @ViewBuilder
    private var content: some View {
        List {
            switch renderer.phase {
            case .preparing, .rendering, .finalizing, .savingToPhotos:
                progressSection
                cancelSection
            case .finished:
                finishedSection
                if renderer.outputURL != nil { shareSection }
                resetSection(label: "Export Another")
            case .failed:
                failedSection
                resetSection(label: "Dismiss")
            case .idle, .cancelled:
                introBlurb
                optionsSection
                startSection
            }
        }
        .navigationTitle("Export Video")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(renderer.isRunning ? "Hide" : "Close") { dismiss() }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = renderer.outputURL {
                ExportShareSheet(items: [url])
                    .ignoresSafeArea()
            }
        }
    }

    // MARK: - Idle (options + start)

    @ViewBuilder
    private var introBlurb: some View {
        Section {
            Text("Renders the route from an overview, follows the runner, then returns to overview to show the result. Camera and speed match your current playback. The export continues in the background even if you close this sheet.")
                .appText(.bodySm)
                .foregroundStyle(.secondary)
                .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private var optionsSection: some View {
        Section("Resolution") {
            Picker("Resolution", selection: $resolutionRaw) {
                ForEach(RouteVideoResolution.allCases) { r in
                    Text(r.label).tag(r.rawValue)
                }
            }
            .pickerStyle(.segmented)
        }

        Section {
            Picker("Quality", selection: $qualityRaw) {
                ForEach(ExportQuality.allCases) { q in
                    Text(q.label).tag(q.rawValue)
                }
            }
            .pickerStyle(.segmented)
            Text(quality.helpText)
                .appText(.bodyXs)
                .foregroundStyle(.secondary)
        } header: {
            Text("Quality")
        } footer: {
            Text("Approx. \(formatExpectedDuration()) of video.")
                .appText(.bodyXs)
                .foregroundStyle(Color.textMuted)
        }
    }

    @ViewBuilder
    private var startSection: some View {
        Section {
            Button {
                startExport()
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: "record.circle")
                    Text("Start Export")
                        .appText(.bodyBaseBold)
                    Spacer()
                }
                .foregroundStyle(Color.accentPrimary)
            }
            .disabled(controller.trackPoints.count < 2)
        }
    }

    // MARK: - Running / finished / failed

    @ViewBuilder
    private var progressSection: some View {
        Section("Rendering") {
            VStack(alignment: .leading, spacing: 10) {
                ProgressView(value: renderer.progress)
                    .tint(Color.accentPrimary)
                Text(renderer.statusMessage.isEmpty
                     ? "\(Int((renderer.progress * 100).rounded()))%"
                     : renderer.statusMessage)
                    .appText(.bodyXs)
                    .foregroundStyle(.secondary)
                Text("You can hide this sheet and keep using the app — the export keeps running in the background.")
                    .appText(.bodyXs)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var cancelSection: some View {
        Section {
            Button(role: .destructive) {
                renderer.cancel()
            } label: {
                HStack { Spacer(); Text("Cancel Export"); Spacer() }
            }
        }
    }

    @ViewBuilder
    private var finishedSection: some View {
        Section {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Color.accentPrimary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Export complete")
                        .appText(.bodyBaseBold)
                    Text(renderer.savedToPhotos
                         ? "Saved to your Photo Library."
                         : "Video saved to a temporary file.")
                        .appText(.bodyXs)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var shareSection: some View {
        Section {
            Button {
                showShareSheet = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share Video")
                        .appText(.bodyBaseBold)
                    Spacer()
                }
                .foregroundStyle(Color.accentPrimary)
            }
        }
    }

    @ViewBuilder
    private var failedSection: some View {
        Section("Export Failed") {
            Text(renderer.errorMessage ?? "Unknown error.")
                .appText(.bodySm)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func resetSection(label: String) -> some View {
        Section {
            Button {
                renderer.reset()
            } label: {
                HStack { Spacer(); Text(label); Spacer() }
            }
        }
    }

    // MARK: - Actions

    private func startExport() {
        let base = quality.preset
        var preset = base
        preset.size = resolution.size
        renderer.reset()
        renderer.start(
            trackPoints: controller.trackPoints,
            raceName: raceName,
            finishTimeSec: finishTimeSec,
            strokeColor: strokeColor,
            configuration: configuration,
            userInterfaceStyle: userInterfaceStyle,
            preset: preset,
            cameraOverride: cameraOverride,
            playbackSpeed: playbackSpeed
        )
    }

    private func formatExpectedDuration() -> String {
        let total = controller.totalDuration
        let preset = quality.preset
        guard total > 0, preset.playbackSpeed > 0 else { return "—" }
        let animSec = min(preset.maxAnimationSeconds, max(2.0, total / preset.playbackSpeed))
        let totalSec = preset.introSeconds + animSec + preset.outroSeconds + preset.holdSeconds
        let m = Int(totalSec) / 60
        let s = Int(totalSec) % 60
        if m > 0 { return String(format: "%dm %02ds", m, s) }
        return String(format: "%ds", s)
    }
#else
    @ViewBuilder
    private var unsupportedContent: some View {
        Text("Video export is only available on iOS.")
            .appText(.bodyBase)
            .foregroundStyle(.secondary)
            .navigationTitle("Export Video")
    }
#endif
}

#if canImport(UIKit)
// MARK: - Quality choices

/// UI 上のクオリティ選択を、内部の `RouteVideoExportPreset` にマップする。
/// 解像度は別軸 (`RouteVideoResolution`) で選ぶため、ここではアニメーションペース
/// (動画の長さと再生倍速) の違いだけを表す。
enum ExportQuality: String, CaseIterable, Identifiable {
    case quick
    case standard
    case detailed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .quick:    return "Quick"
        case .standard: return "Standard"
        case .detailed: return "Detailed"
        }
    }

    var helpText: String {
        switch self {
        case .quick:    return "Shortest video. The route plays at high speed."
        case .standard: return "Balanced length. Good default for sharing."
        case .detailed: return "Longest video. Shows the route in more detail."
        }
    }

    var preset: RouteVideoExportPreset {
        switch self {
        case .quick:    return .quick
        case .standard: return .standard
        case .detailed: return .detailed
        }
    }
}
#endif
