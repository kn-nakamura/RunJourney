import SwiftUI
#if os(iOS)
import ReplayKit
import UIKit

/// `RPPreviewViewController` を SwiftUI で扱えるラッパー。
/// 動画プレビュー → 写真ライブラリ保存 or 共有 or 破棄、を OS 標準UIで提供する。
struct RPPreviewWrapper: UIViewControllerRepresentable {
    let preview: RPPreviewViewController
    let onFinish: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    func makeUIViewController(context: Context) -> RPPreviewViewController {
        preview.previewControllerDelegate = context.coordinator
        // iPad は presentationStyle が popover/formSheetになることがあるので調整
        preview.modalPresentationStyle = .fullScreen
        return preview
    }

    func updateUIViewController(_ uiViewController: RPPreviewViewController, context: Context) {}

    final class Coordinator: NSObject, RPPreviewViewControllerDelegate {
        let onFinish: () -> Void
        init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }

        func previewControllerDidFinish(_ previewController: RPPreviewViewController) {
            previewController.dismiss(animated: true) { [onFinish] in onFinish() }
        }
    }
}
#endif
