import SwiftUI
#if canImport(UIKit)
import UIKit
import MapKit
#endif

/// 動画書き出しシート。
/// プリセットを選んで開始すると `RouteVideoRenderer.shared` がバックグラウンドで
/// フレーム単位の書き出しを行うため、このシートを閉じても書き出しは継続される。
struct ExportSheet: View {
    @Bindable var controller: PlaybackController
    let raceName: String?
    let finishTimeSec: Double?
#if canImport(UIKit)
    let strokeColor: UIColor
    let configuration: MKMapConfiguration
    let userInterfaceStyle: UIUserInterfaceStyle
#endif

    @Environment(\.dismiss) private var dismiss

#if canImport(UIKit)
    @State private var renderer = RouteVideoRenderer.shared
    @State private var selectedPreset: PresetChoice = .standard
    @State private var showShareSheet: Bool = false
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
            Section {
                Text("Video export renders the route from an overview, follows the runner, then returns to overview to show the final result. Export continues in the background even if you close this sheet.")
                    .appText(.bodySm)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }

            if renderer.isRunning {
                progressSection
            } else if renderer.phase == .finished {
                finishedSection
            } else if renderer.phase == .failed {
                failedSection
            } else {
                presetSection
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
    }

    // MARK: - Preset section

    private enum PresetChoice: String, CaseIterable, Identifiable {
        case quick, standard, detailed
        var id: String { rawValue }

        var title: String {
            switch self {
            case .quick:    return "Quick"
            case .standard: return "Standard"
            case .detailed: return "Detailed"
            }
        }

        var subtitle: String {
            switch self {
            case .quick:    return "~12 s · 128× playback"
            case .standard: return "~50 s · 32× playback"
            case .detailed: return "~80 s · 8× playback"
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

    @ViewBuilder
    private var presetSection: some View {
        Section("Preset") {
            ForEach(PresetChoice.allCases) { choice in
                Button {
                    selectedPreset = choice
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(choice.title)
                                .appText(.bodyBase)
                                .foregroundStyle(Color.textPrimary)
                            Text(choice.subtitle)
                                .appText(.bodyXs)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if selectedPreset == choice {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentPrimary)
                        }
                    }
                }
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

    // MARK: - Progress section

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

    // MARK: - Finished section

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

    // MARK: - Failed section

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
            preset: selectedPreset.preset
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
