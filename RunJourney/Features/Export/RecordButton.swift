import SwiftUI
#if os(iOS)
import ReplayKit
#endif

/// フライスルー画面に置く録画ボタン。
/// - 状態: idle → starting → recording → stopping → idle / error
/// - 録画停止後はOS標準のプレビューで保存・共有できる
struct RecordButton: View {
    @State private var exporter = VideoExporter()
#if os(iOS)
    @State private var preview: RPPreviewViewController?
#endif
    @State private var errorMessage: String?

    var body: some View {
#if os(iOS)
        button
            .sheet(item: previewBinding) { vc in
                RPPreviewWrapper(preview: vc) {
                    preview = nil
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

    private var previewBinding: Binding<RPPreviewItem?> {
        Binding(
            get: { preview.map(RPPreviewItem.init) },
            set: { if $0 == nil { preview = nil } }
        )
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
            await exporter.startRecording()
            if case .error(let msg) = exporter.state {
                errorMessage = msg
            }
        case .recording:
            if let vc = await exporter.stopRecording() {
                preview = vc
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
/// `RPPreviewViewController` をsheetのitemとして扱うためのIdentifiableラッパー。
struct RPPreviewItem: Identifiable {
    let id = UUID()
    let controller: RPPreviewViewController
    init(_ c: RPPreviewViewController) { self.controller = c }
}

extension RPPreviewWrapper {
    init(preview item: RPPreviewItem, onFinish: @escaping () -> Void) {
        self.init(preview: item.controller, onFinish: onFinish)
    }
}
#endif
