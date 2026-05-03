import SwiftUI
#if os(iOS)
import ReplayKit
#endif

/// 録画プリセット選択シート。
/// 選択後「Start Export」で: rewind → 録画開始 → 自動再生 → 終了で録画停止 → ShareSheet。
struct ExportSheet: View {
    @Bindable var controller: PlaybackController
    @Environment(\.dismiss) private var dismiss

    @State private var exporter = VideoExporter()
    @State private var selectedPreset: ExportPreset = .speed32x
    @State private var errorMessage: String? = nil
    @State private var isExporting = false

#if os(iOS)
    @State private var previewItem: RPPreviewItem? = nil
#endif

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Route playback is recorded automatically at the selected speed. The resulting video can be saved to your Photo Library or shared.")
                        .appText(.bodySm)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }

                Section("Export Speed") {
                    ForEach(ExportPreset.allCases) { preset in
                        Button {
                            selectedPreset = preset
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(preset.title)
                                        .appText(.bodyBase)
                                        .foregroundStyle(Color.textPrimary)
                                    Text(preset.subtitle(totalDuration: controller.totalDuration))
                                        .appText(.bodyXs)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selectedPreset == preset {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentPrimary)
                                }
                            }
                        }
                    }
                }

                Section {
                    Button {
                        Task { await startExport() }
                    } label: {
                        HStack {
                            Spacer()
                            if isExporting {
                                ProgressView()
                                    .tint(Color.accentPrimary)
                                    .padding(.trailing, 8)
                                Text("Recording…")
                                    .appText(.bodyBaseBold)
                                    .foregroundStyle(Color.accentPrimary)
                            } else {
                                Image(systemName: "record.circle")
                                Text("Start Export")
                                    .appText(.bodyBaseBold)
                            }
                            Spacer()
                        }
                        .foregroundStyle(isExporting ? Color.secondary : Color.accentPrimary)
                    }
                    .disabled(isExporting || !exportAvailable)
                }

                if !exportAvailable {
                    Section {
                        Label("Screen recording is not available on this device.", systemImage: "exclamationmark.triangle")
                            .appText(.bodyXs)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Export Video")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isExporting)
                }
            }
            .alert("Export Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
#if os(iOS)
            .sheet(item: $previewItem) { item in
                RPPreviewWrapper(preview: item.controller) {
                    previewItem = nil
                    dismiss()
                }
                .ignoresSafeArea()
            }
#endif
        }
    }

    private var exportAvailable: Bool {
#if os(iOS)
        RPScreenRecorder.shared().isAvailable
#else
        false
#endif
    }

    // MARK: - Export flow

    private func startExport() async {
#if os(iOS)
        isExporting = true
        // 1. Rewind and set speed
        await MainActor.run {
            controller.seek(to: 0)
            controller.changeSpeed(selectedPreset.speed)
        }
        // 2. Start recording
        await exporter.startRecording()
        if case .error(let msg) = exporter.state {
            await MainActor.run { errorMessage = msg; isExporting = false }
            return
        }
        // 3. Start playback
        await MainActor.run { controller.play() }
        // 4. Wait for playback to finish (poll every 0.5 s)
        await waitForPlaybackEnd()
        // 5. Stop recording
        await MainActor.run { controller.pause() }
        if let vc = await exporter.stopRecording() {
            await MainActor.run {
                previewItem = RPPreviewItem(controller: vc)
                isExporting = false
            }
        } else {
            if case .error(let msg) = exporter.state {
                await MainActor.run { errorMessage = msg }
            }
            await MainActor.run { isExporting = false }
        }
#endif
    }

    private func waitForPlaybackEnd() async {
        // Poll until currentTime reaches totalDuration or user somehow pauses.
        // Use a task sleep loop with 0.5s intervals.
        while true {
            try? await Task.sleep(for: .milliseconds(500))
            let done = await MainActor.run {
                controller.currentTime >= controller.totalDuration * 0.999
                    || !controller.isPlaying
            }
            if done { break }
        }
    }
}

// MARK: - Export Preset

enum ExportPreset: String, CaseIterable, Identifiable {
    case speed8x   = "8x"
    case speed32x  = "32x"
    case speed128x = "128x"

    var id: String { rawValue }

    var speed: Double {
        switch self {
        case .speed8x:   return 8
        case .speed32x:  return 32
        case .speed128x: return 128
        }
    }

    var title: String {
        switch self {
        case .speed8x:   return "8× — Detailed"
        case .speed32x:  return "32× — Standard"
        case .speed128x: return "128× — Fast"
        }
    }

    func subtitle(totalDuration: Double) -> String {
        guard totalDuration > 0 else { return "" }
        let approxSec = totalDuration / speed
        let m = Int(approxSec) / 60
        let s = Int(approxSec) % 60
        let durationStr = m > 0
            ? String(format: "~%d min %d sec video", m, s)
            : String(format: "~%d sec video", s)
        return durationStr
    }
}
