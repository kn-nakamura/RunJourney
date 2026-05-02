import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// MapKit (内部 UIKit/AppKit) は SwiftUI の `.preferredColorScheme()` を必ずしも見ないため、
/// UIKit の `overrideUserInterfaceStyle` / AppKit の `NSAppearance` を直接強制するラッパー。
/// 子 SwiftUI ビュー（とその中の MapKit ビュー）はこれで指定したカラースキームで描画される。
struct ColorSchemeOverride<Content: View>: View {
    let scheme: ColorScheme?
    let content: () -> Content

    init(scheme: ColorScheme?, @ViewBuilder content: @escaping () -> Content) {
        self.scheme = scheme
        self.content = content
    }

    var body: some View {
        OverrideRepresentable(scheme: scheme, content: content)
            .environment(\.colorScheme, scheme ?? .dark)
    }
}

#if os(iOS)
/// `UIHostingController` のサブクラス。`safeAreaInsets` を常に `.zero` に強制する。
/// SwiftUI 親で `.ignoresSafeArea(.all, edges: .top)` をかけても、
/// UIHostingController 内に閉じた SwiftUI 階層では再びシステムの safe area
/// (ステータスバー領域) が現れてフルスクリーン描画を阻害する。
/// このクラスでホスト境界の safe area を無効化することで、内側の SwiftUI ビュー
/// (例: MKMapView) が画面上端まで広がる。
private final class FullBleedHostingController<Content: View>: UIHostingController<Content> {
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        // `additionalSafeAreaInsets` を負方向にセットして system inset を打ち消す。
        // top のみ。bottom はタブバー・ホームインジケータを尊重するため触らない。
        let top = view.safeAreaInsets.top - additionalSafeAreaInsets.top
        if top > 0 {
            additionalSafeAreaInsets = UIEdgeInsets(top: -top, left: 0, bottom: 0, right: 0)
        }
    }
}

private struct OverrideRepresentable<Content: View>: UIViewControllerRepresentable {
    let scheme: ColorScheme?
    let content: () -> Content

    func makeUIViewController(context: Context) -> UIHostingController<Content> {
        let host = FullBleedHostingController(rootView: content())
        host.view.backgroundColor = .clear
        host.overrideUserInterfaceStyle = uiStyle(scheme)
        return host
    }

    func updateUIViewController(_ vc: UIHostingController<Content>, context: Context) {
        vc.rootView = content()
        vc.overrideUserInterfaceStyle = uiStyle(scheme)
    }

    private func uiStyle(_ s: ColorScheme?) -> UIUserInterfaceStyle {
        guard let s else { return .unspecified }
        return s == .dark ? .dark : .light
    }
}
#elseif os(macOS)
private struct OverrideRepresentable<Content: View>: NSViewControllerRepresentable {
    let scheme: ColorScheme?
    let content: () -> Content

    func makeNSViewController(context: Context) -> NSHostingController<Content> {
        let host = NSHostingController(rootView: content())
        host.view.appearance = appearance(scheme)
        return host
    }

    func updateNSViewController(_ vc: NSHostingController<Content>, context: Context) {
        vc.rootView = content()
        vc.view.appearance = appearance(scheme)
    }

    private func appearance(_ s: ColorScheme?) -> NSAppearance? {
        guard let s else { return nil }
        return NSAppearance(named: s == .dark ? .darkAqua : .aqua)
    }
}
#endif
