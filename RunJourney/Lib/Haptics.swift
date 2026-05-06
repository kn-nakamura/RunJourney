import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// プラットフォーム差分を吸収する触覚フィードバックのファサード。
/// iPhone 実機でのみ振動し、iPad / Mac Catalyst / Mac (native) / Vision では no-op。
/// Taptic Engine 非搭載の iPad もここで黙って無視するので、呼び出し側は
/// プラットフォーム判定を毎回書かずに `Haptics.tap()` のような短い命令で済む。
enum Haptics {

    /// 軽いタップ。タブ / セグメント / ピル / Distance Tab など軽めの選択に使う。
    static func tap() {
        impact(.light)
    }

    /// 中程度のタップ。明確な「決定」を伴うアクション (FAB を押す、ピンを選ぶ等)。
    static func selection() {
#if os(iOS) && !targetEnvironment(macCatalyst)
        guard isHapticsCapable else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
#endif
    }

    /// 強めのタップ。Save / Apply など「成立した」感を出したいとき。
    static func success() {
#if os(iOS) && !targetEnvironment(macCatalyst)
        guard isHapticsCapable else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
#endif
    }

    /// 警告の振動。削除前の確認や、上限到達など。
    static func warning() {
#if os(iOS) && !targetEnvironment(macCatalyst)
        guard isHapticsCapable else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
#endif
    }

    /// エラー振動。失敗系のフィードバック (操作が拒否された等)。
    static func error() {
#if os(iOS) && !targetEnvironment(macCatalyst)
        guard isHapticsCapable else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
#endif
    }

    /// 任意強度のインパクト。値の連続調整 (ステッパー等) で軽く使う想定。
    static func impact(_ style: ImpactStyle = .light) {
#if os(iOS) && !targetEnvironment(macCatalyst)
        guard isHapticsCapable else { return }
        let generator = UIImpactFeedbackGenerator(style: style.uiKitStyle)
        generator.prepare()
        generator.impactOccurred()
#endif
    }

    enum ImpactStyle {
        case light
        case medium
        case heavy
        case soft
        case rigid

#if os(iOS) && !targetEnvironment(macCatalyst)
        var uiKitStyle: UIImpactFeedbackGenerator.FeedbackStyle {
            switch self {
            case .light:  return .light
            case .medium: return .medium
            case .heavy:  return .heavy
            case .soft:   return .soft
            case .rigid:  return .rigid
            }
        }
#endif
    }

#if os(iOS) && !targetEnvironment(macCatalyst)
    /// Taptic Engine の有無を粗く判定する。iPad は idiom が `.pad` で原則振動デバイスを
    /// 持たないので no-op に倒す (Touch ID 世代の iPad に振動を送るとシステム側で空振り
    /// するだけだが、無駄な FeedbackGenerator 生成を避ける)。
    private static var isHapticsCapable: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }
#endif
}
