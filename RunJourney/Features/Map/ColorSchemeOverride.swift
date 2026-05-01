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
private struct OverrideRepresentable<Content: View>: UIViewControllerRepresentable {
    let scheme: ColorScheme?
    let content: () -> Content

    func makeUIViewController(context: Context) -> UIHostingController<Content> {
        let host = UIHostingController(rootView: content())
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
