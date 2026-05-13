import SwiftUI
#if canImport(UIKit)
import UIKit
import MapKit
#endif

/// 動画書き出しシート。
/// 開始前にプレビューでカメラ角度・距離・回転・再生速度を調整でき、
/// 開始後は `RouteVideoRenderer.shared` がバックグラウンドで書き出しを継続するため、
/// このシートを閉じてもエクスポートはそのまま進行する。
struct ExportSheet: View {
    @Bindable var controller: PlaybackController
    let raceName: String?
    let finishTimeSec: Double?
#if canImport(UIKit)
    let strokeColor: UIColor
    let configuration: MKMapConfiguration
    let userInterfaceStyle: UIUserInterfaceStyle
    /// RouteFlythruView 側でユーザが既に触っていた値があれば、シート起動時の
    /// 初期値として引き継ぐ。
    var initialAngle: Double? = nil
    var initialDistance: Double? = nil
    var initialRotation: Double? = nil
    var initialSpeed: Double? = nil
#endif

    @Environment(\.dismiss) private var dismiss

#if canImport(UIKit)
    @State private var renderer = RouteVideoRenderer.shared
    @State private var showShareSheet: Bool = false

    // カメラ・スピード設定 (onAppear で実値を入れる)
    @State private var angle: Double = 60
    @State private var distance: Double = 1500
    @State private var rotation: Double = 0
    @State private var playbackSpeed: Double = 32
    @State private var previewProgress: Double = 0.5

    // プレビュー画像
    @State private var previewImage: UIImage? = nil
    @State private var previewTask: Task<Void, Never>? = nil
    @State private var previewVersion: Int = 0
    @State private var previewSize: CGSize = CGSize(width: 360, height: 200)
#endif

    var body: some View {
        NavigationStack {
#if canImport(UIKit)
            content
#else
            unsupportedContent
#endif
        }
    }

#if canImport(UIKit)
    @ViewBuilder
    private var content: some View {
        List {
            if renderer.isRunning {
                progressSection
            } else if renderer.phase == .finished {
                finishedSection
            } else if renderer.phase == .failed {
                failedSection
            } else {
                introBlurb
                previewSection
                cameraSection
                speedSection
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
                ShareSheet(items: [url])
                    .ignoresSafeArea()
            }
        }
        .onAppear { onAppear() }
        .onDisappear { previewTask?.cancel() }
    }

    // MARK: - Sections

    @ViewBuilder
    private var introBlurb: some View {
        Section {
            Text("Renders the route from an overview, follows the runner, then returns to overview to show the result. Export continues in the background even if you close this sheet.")
                .appText(.bodySm)
                .foregroundStyle(.secondary)
                .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private var previewSection: some View {
        Section("Preview") {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    if let image = previewImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.bgSecondary)
                            ProgressView().tint(Color.accentPrimary)
                        }
                        .aspectRatio(16 / 9, contentMode: .fit)
                    }
                }
                .frame(maxWidth: .infinity)
                .overlay(alignment: .topLeading) {
                    Text("\(Int((previewProgress * 100).rounded()))% of route")
                        .appText(.bodyXs)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.black.opacity(0.55), in: Capsule())
                        .foregroundStyle(.white)
                        .padding(8)
                }

                HStack {
                    Text("Preview Position")
                        .appText(.bodyXs)
                        .foregroundStyle(.secondary)
                    Slider(value: $previewProgress, in: 0...1)
                        .tint(Color.accentPrimary)
                        .onChange(of: previewProgress) { _, _ in schedulePreview() }
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var cameraSection: some View {
        Section("Camera") {
            sliderRow(
                label: "Angle",
                value: $angle,
                range: 0...180,
                format: "%.0f°",
                onCommit: { schedulePreview() }
            )
            sliderRow(
                label: "Rotation",
                value: $rotation,
                range: -180...180,
                format: "%.0f°",
                onCommit: { schedulePreview() }
            )
            sliderRow(
                label: "Distance",
                value: $distance,
                range: 300...8000,
                format: "%.0f m",
                onCommit: { schedulePreview() }
            )

            Button {
                resetCameraToAuto()
            } label: {
                HStack { Spacer(); Text("Reset to Auto").appText(.bodyXs); Spacer() }
                    .foregroundStyle(Color.accentPrimary)
            }
        }
    }

    @ViewBuilder
    private var speedSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Playback Speed")
                        .appText(.bodyXs)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("≈ \(formatExpectedDuration()) video")
                        .appText(.bodyXs)
                        .foregroundStyle(Color.textMuted)
                }
                speedGrid
            }
        }
    }

    private var speedGrid: some View {
        let presets = PlaybackController.speedPresets
        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5),
            spacing: 6
        ) {
            ForEach(presets, id: \.self) { preset in
                let isActive = playbackSpeed == preset
                Button {
                    playbackSpeed = preset
                } label: {
                    Text("\(formatSpeed(preset))×")
                        .appText(.codeXsBold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(isActive ? Color.accentPrimary : Color.bgSecondary,
                                    in: RoundedRectangle(cornerRadius: 6))
                        .foregroundStyle(isActive ? Color.black : Color.textPrimary)
                }
                .buttonStyle(.plain)
            }
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

    // MARK: - Progress / finished / failed

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
                Text("You can hide this sheet and keep using the app — the video will keep rendering and be saved to Photos when done.")
                    .appText(.bodyXs)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
        }
        Section {
            Button(role: .destructive) {
                renderer.cancel()
            } label: {
                HStack { Spacer(); Text("Cancel"); Spacer() }
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

        if renderer.outputURL != nil {
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

        Section {
            Button {
                renderer.reset()
            } label: {
                HStack { Spacer(); Text("Export Another"); Spacer() }
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
        Section {
            Button {
                renderer.reset()
            } label: {
                HStack { Spacer(); Text("Dismiss"); Spacer() }
            }
        }
    }

    // MARK: - Helpers

    private func sliderRow(
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        format: String,
        onCommit: @escaping () -> Void
    ) -> some View {
        HStack {
            Text(label)
                .appText(.bodyXs)
                .foregroundStyle(.secondary)
                .frame(width: 78, alignment: .leading)
            Slider(value: value, in: range)
                .tint(Color.accentPrimary)
                .onChange(of: value.wrappedValue) { _, _ in onCommit() }
            Text(String(format: format, value.wrappedValue))
                .appText(.codeXs)
                .foregroundStyle(Color.textPrimary)
                .frame(width: 64, alignment: .trailing)
        }
    }

    private func onAppear() {
        let totalDistanceKm = (controller.trackPoints.last?.distanceM ?? 0) / 1000
        let profile = PlaybackMath.followCameraProfile(distanceKm: totalDistanceKm, emphasis: .high)
        angle = initialAngle ?? profile.angle
        distance = initialDistance ?? profile.distance
        rotation = initialRotation ?? 0
        playbackSpeed = initialSpeed ?? PlaybackMath.defaultPlaybackSpeed(
            totalTimeSec: controller.totalDuration,
            presets: PlaybackController.speedPresets
        )
        schedulePreview()
    }

    private func resetCameraToAuto() {
        let totalDistanceKm = (controller.trackPoints.last?.distanceM ?? 0) / 1000
        let profile = PlaybackMath.followCameraProfile(distanceKm: totalDistanceKm, emphasis: .high)
        angle = profile.angle
        distance = profile.distance
        rotation = 0
        schedulePreview()
    }

    private func currentCameraOverride() -> FollowCameraOverride {
        FollowCameraOverride(angle: angle, distance: distance, rotation: rotation)
    }

    private func schedulePreview() {
        previewTask?.cancel()
        previewVersion += 1
        let version = previewVersion
        let trackPoints = controller.trackPoints
        let progress = previewProgress
        let override = currentCameraOverride()
        let size = previewSize
        let stroke = strokeColor
        let cfg = configuration
        let style = userInterfaceStyle
        previewTask = Task {
            try? await Task.sleep(nanoseconds: 220_000_000)
            if Task.isCancelled { return }
            let image: UIImage? = try? await RouteVideoRenderer.renderPreviewFrame(
                trackPoints: trackPoints,
                atProgress: progress,
                size: size,
                strokeColor: stroke,
                configuration: cfg,
                userInterfaceStyle: style,
                cameraOverride: override
            )
            if Task.isCancelled { return }
            await MainActor.run {
                if version == previewVersion { previewImage = image }
            }
        }
    }

    private func formatSpeed(_ s: Double) -> String {
        if s == s.rounded() { return "\(Int(s))" }
        return String(format: "%.1f", s)
    }

    private func formatExpectedDuration() -> String {
        let total = controller.totalDuration
        guard total > 0, playbackSpeed > 0 else { return "—" }
        let preset = RouteVideoExportPreset.standard
        let animSec = min(preset.maxAnimationSeconds, max(2.0, total / playbackSpeed))
        let totalSec = preset.introSeconds + animSec + preset.outroSeconds + preset.holdSeconds
        let m = Int(totalSec) / 60
        let s = Int(totalSec) % 60
        if m > 0 { return String(format: "%dm %02ds", m, s) }
        return String(format: "%ds", s)
    }

    // MARK: - Actions

    private func startExport() {
        renderer.reset()
        renderer.start(
            trackPoints: controller.trackPoints,
            raceName: raceName,
            finishTimeSec: finishTimeSec,
            strokeColor: strokeColor,
            configuration: configuration,
            userInterfaceStyle: userInterfaceStyle,
            preset: .standard,
            cameraOverride: currentCameraOverride(),
            playbackSpeed: playbackSpeed
        )
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
/// 共有シート。完了した動画ファイルを Photos に保存していないユーザでも、AirDrop や
/// メッセージ等から動画を取り出せるようにする。
private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
#endif
