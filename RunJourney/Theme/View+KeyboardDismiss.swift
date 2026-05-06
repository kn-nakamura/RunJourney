import SwiftUI
#if os(iOS)
import UIKit
#endif

/// 数字キーボード (`.numberPad` / `.decimalPad`) は Return キーが無く、入力後に
/// 閉じる手段がユーザに見えない。これを補う共通モディファイアをまとめる。
///
/// - `.keyboardCloseToolbar()`
///   Keyboard placement のツールバーに右寄せの "Close" ボタンを追加する。
///   ボタン押下で first responder を resign し、キーボードを閉じる。
/// - `.dismissKeyboardOnBackgroundTap()`
///   画面のどこかをタップしたらキーボードを閉じる。`UIWindow` レベルに
///   `cancelsTouchesInView = false` の `UITapGestureRecognizer` を 1 度だけ
///   差し込む方式なので、SwiftUI 側の Button / Form 行タップを一切奪わない。
extension View {
    /// 画面のルートに 1 度だけ付ければ、配下の TextField がフォーカス時に
    /// "Close" ボタンを持つキーボードツールバーを表示する。
    func keyboardCloseToolbar() -> some View {
        modifier(KeyboardCloseToolbarModifier())
    }

    /// 画面のどこかをタップしたら現在開いているキーボードを閉じる。
    /// 実体は `UIWindow` への gesture recognizer 注入で、SwiftUI のジェスチャ
    /// チェーンを汚さない (＝ Form の Button タップが効かなくなる事故を防ぐ)。
    func dismissKeyboardOnBackgroundTap() -> some View {
        modifier(DismissKeyboardOnTapModifier())
    }
}

private struct KeyboardCloseToolbarModifier: ViewModifier {
    func body(content: Content) -> some View {
#if os(iOS)
        content.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Close") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                }
            }
        }
#else
        content
#endif
    }
}

private struct DismissKeyboardOnTapModifier: ViewModifier {
    func body(content: Content) -> some View {
#if os(iOS)
        content.background(WindowKeyboardDismissInstaller())
#else
        content
#endif
    }
}

#if os(iOS)
/// 自身の `window` に対して `UITapGestureRecognizer` を 1 度だけ取り付け、
/// 画面のどこをタップしても first responder を resign させる仕掛け。
/// `cancelsTouchesInView = false` なので、Button / Form 行 / NavigationLink
/// 等のタップは奪われず、キーボード閉じだけが副作用として走る。
private struct WindowKeyboardDismissInstaller: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let view = ProbeView()
        view.isUserInteractionEnabled = false
        view.onMove = { window in
            Self.install(on: window, coordinator: context.coordinator)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    /// 同一 window に 2 度差し込まないためのマーカー名。
    private static let recognizerName = "RunJourney.DismissKeyboardOnTap"

    private static func install(on window: UIWindow, coordinator: Coordinator) {
        if window.gestureRecognizers?.contains(where: { $0.name == recognizerName }) == true {
            return
        }
        let tap = UITapGestureRecognizer(
            target: coordinator,
            action: #selector(Coordinator.handleTap)
        )
        tap.name = recognizerName
        tap.cancelsTouchesInView = false
        tap.delaysTouchesBegan = false
        tap.delaysTouchesEnded = false
        tap.requiresExclusiveTouchType = false
        tap.delegate = coordinator
        window.addGestureRecognizer(tap)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        @objc func handleTap() {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil, from: nil, for: nil
            )
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }

    /// `didMoveToWindow` を SwiftUI に橋渡しするだけの薄い UIView。
    private final class ProbeView: UIView {
        var onMove: ((UIWindow) -> Void)?
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if let window { onMove?(window) }
        }
    }
}
#endif
