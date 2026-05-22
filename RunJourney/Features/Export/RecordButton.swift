import SwiftUI
#if os(iOS)
import ReplayKit
#endif

/// フライスルー画面に置く録画ボタン。
/// - 状態: idle → starting → recording → stopping → idle / error
/// - 録画停止後はOS標準のプレビューで保存・共有できる
/// - `exporter` を親から受け取ることで、親側で `exporter.state` を観察して
///   録画中だけ他のUIをフェードアウトさせるなどの制御ができる。
struct RecordButton: View {
    /// 親が所有する `VideoExporter`。録画状態を共有する。
    @Bindable var exporter: VideoExporter
    /// 録画開始 (state が `.recording` に遷移した直後) に呼ばれる。
    /// 典型用途: 再生コントローラを seek(to: 0) + play() してフライスルーを頭から流す。
    /// ReplayKit の許可ダイアログの後に呼ばれるので、ダイアログ中に再生が先行する事故を防ぐ。
    var onRecordingWillStart: (() -> Void)? = nil
    /// 録画停止の直前に呼ばれる。典型用途: 再生コントローラを pause。
    var onRecordingDidStop: (() -> Void)? = nil

#if os(iOS)
    @State private var previewItem: RPPreviewItem?
#endif
    @State private var errorMessage: String?

    var body: some View {
#if os(iOS)
        button
            .sheet(item: $previewItem) { item in
                RPPreviewWrapper(preview: item.controller) {
                    previewItem = nil
                }
                .ignoresSafeArea()
            }
            .alert("Recording Error", isPresented: errorAlertBinding, presenting: errorMessage) { _ in
                Button("OK") { errorMessage = nil }
            } message: { msg in
                Text(msg)
            }
#else
        EmptyView()
#endif
    }

#if os(iOS)
    @ViewBuilder
    private var button: some View {
        Button {
            Task { await toggleRecording() }
        } label: {
            ZStack {
                Circle()
                    .fill(isRecording ? Color.red : Color.bgSecondary)
                    .frame(width: 56, height: 56)
                    .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1.5))
                    .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 2)

                if isRecording {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white)
                        .frame(width: 18, height: 18)
                } else {
                    Circle()
                        .fill(.red)
                        .frame(width: 22, height: 22)
                }
            }
            .scaleEffect(isRecording ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isRecording)
        }
        .disabled(isBusy || !exporter.isAvailable)
        .accessibilityLabel(isRecording ? "Stop Recording" : "Start Recording")
    }

    private var isRecording: Bool {
        if case .recording = exporter.state { return true }
        return false
    }

    private var isBusy: Bool {
        switch exporter.state {
        case .starting, .stopping: return true
        default: return false
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func toggleRecording() async {
        switch exporter.state {
        case .idle, .error:
            await exporter.startRecording()
            switch exporter.state {
            case .recording:
                // 許可ダイアログを抜けて録画が確定したタイミングで呼ぶ。
                // 早すぎると、システムダイアログ中に再生が進んで頭出しがズレる。
                onRecordingWillStart?()
            case .error(let msg):
                errorMessage = msg
            default:
                break
            }
        case .recording:
            onRecordingDidStop?()
            if let vc = await exporter.stopRecording() {
                previewItem = RPPreviewItem(controller: vc)
            } else if case .error(let msg) = exporter.state {
                errorMessage = msg
            }
        default:
            break
        }
    }
#endif
}

#if os(iOS)
/// `RPPreviewViewController` を sheet(item:) のIdentifiable Item として扱うラッパー。
/// id は init で固定生成されるので、同じ controller 参照に対しては同じ id を維持する。
struct RPPreviewItem: Identifiable {
    let id = UUID()
    let controller: RPPreviewViewController
}
#endif
