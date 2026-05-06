import SwiftUI

/// 数字キーボード (`.numberPad` / `.decimalPad`) は Return キーが無く、入力後に
/// 閉じる手段がユーザに見えない。これを補う共通モディファイアをまとめる。
///
/// - `.keyboardCloseToolbar()`
///   Keyboard placement のツールバーに右寄せの "Close" ボタンを追加する。
///   ボタン押下で first responder を resign し、キーボードを閉じる。
/// - `.dismissKeyboardOnBackgroundTap()`
///   画面のどこかをタップしたらキーボードを閉じる。`.simultaneousGesture` で
///   付与するので、Button や TextField の自前タップを奪わない。
extension View {
    /// 画面のルートに 1 度だけ付ければ、配下の TextField がフォーカス時に
    /// "Close" ボタンを持つキーボードツールバーを表示する。
    func keyboardCloseToolbar() -> some View {
        modifier(KeyboardCloseToolbarModifier())
    }

    /// 画面のどこかをタップしたら現在開いているキーボードを閉じる。
    /// `.simultaneousGesture` を使うので Button タップなどは通常通り動く。
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
        content.simultaneousGesture(
            TapGesture().onEnded { _ in
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
            }
        )
#else
        content
#endif
    }
}
