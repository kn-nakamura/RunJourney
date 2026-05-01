import SwiftUI
#if os(iOS)
import ReplayKit
#endif

/// フライスルー画面に置く録画ボタン。
/// - 状態: idle → starting → recording → stopping → idle / error
/// - 録画停止後はOS標準のプレビューで保存・共有できる
struct RecordButton: View {
    /// 録画開始/停止イベントを親に通知。typically: 親で再生コントローラを pause する。
    var onRecordingWillStart: (() -> Void)? = nil
    var onRecordingDidStop: (() -> Void)? = nil

    @State private var exporter = VideoExporter()
#if os(iOS)
    /// プレビューシートの状態。安定した id を持つ Item として保持し、
    /// 不要な sheet 再表示を防ぐ（@State 1個で id 不変）。
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
            .alert("録画エラー", isPresented: errorAlertBinding, presenting: errorMessage) { _ in
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
                    .frame(width: 44, height: 44)
                    .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))

                if isRecording {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white)
                        .frame(width: 14, height: 14)
                } else {
                    Circle()
                        .fill(.red)
                        .frame(width: 18, height: 18)
                }
            }
            .scaleEffect(isRecording ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isRecording)
        }
        .disabled(isBusy)
        .accessibilityLabel(isRecording ? "録画停止" : "録画開始")
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
        case .idle:
            // 録画開始前に親へ通知（再生をいったん止めたいなら親側で対応）
            onRecordingWillStart?()
            await exporter.startRecording()
            if case .error(let msg) = exporter.state {
                errorMessage = msg
            }
        case .recording:
            // 停止前に親へ通知（再生を pause させて Map のカメラ更新を止める）
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
