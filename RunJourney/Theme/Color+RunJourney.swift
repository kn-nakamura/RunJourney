import SwiftUI
#if os(iOS)
import UIKit
#endif

/// Web版 marathon-record-app からテーマカラーを継承。
///
/// 設計トーン:
/// - **Dark** = 夜のネオン (ほぼ黒 × 蛍光イエローグリーン)
/// - **Light** = 昼の自然光 (パーチメント系オフホワイト × 自然素材アクセント)
///
/// テーマ依存トークン (背景/テキスト/border/badge/race-pin) は UIColor の `dynamicProvider`
/// で `userInterfaceStyle` に追従させ、`.preferredColorScheme()` カスケードで自動切替する。
/// `accentPrimary` だけは `AccentChoice` をユーザーが選べるため、UserDefaults を読みに行く。
extension Color {

    // MARK: - Brand background palette (theme-dynamic)

    /// アプリ全体の基調背景。Dark = ほぼ黒, Light = 暖かいパーチメント。
    static var bgPrimary: Color {
        dynamicColor(dark: 0x0A0A0F, light: 0xF2EEE6)
    }
    /// カード背景。Light は基調より僅かに浮いて見えるクリーム。
    static var bgSecondary: Color {
        dynamicColor(dark: 0x13131A, light: 0xFBF8F2)
    }
    /// 押下/アクティブ状態。Light は基調より沈ませて反応を出す。
    static var bgTertiary: Color {
        dynamicColor(dark: 0x1C1C28, light: 0xE5E0D6)
    }
    /// Divider / 細枠。Light は暖灰色で柔らかく区切る。
    static var borderColor: Color {
        dynamicColor(dark: 0x2A2A3A, light: 0xD6D0C4)
    }

    // MARK: - Text (theme-dynamic)

    static var textPrimary: Color {
        dynamicColor(dark: 0xF0F0F0, light: 0x1B1814)
    }
    static var textMuted: Color {
        dynamicColor(dark: 0x6B7280, light: 0x76705F)
    }

    // MARK: - Accent (user-customizable)

    /// ブランドアクセント。Settings → Appearance で `AccentChoice` をユーザーが選べる。
    /// テーマと選択 hex を `UIColor(dynamicProvider:)` 経由で動的に解決する。
    /// アクセントだけ変えても trait は変わらないため、`RunJourneyApp` 側で `.id(...)` を
    /// 付けてツリー再構築する仕組みと組み合わせて使う。
    static var accentPrimary: Color {
        dynamicAccent(\.hex)
    }
    /// 抑えアクセント (PB バッジの裏トーンなど)。
    static var accentDim: Color {
        dynamicAccent(\.dimHex)
    }

    // MARK: - Badges

    /// PB（Personal Best）バッジ色 — アクセントに連動。
    static var pbBadge: Color { accentPrimary }
    /// SB（Season Best）バッジ色 — シルバー (Light は暖シルバー)。
    static var sbBadge: Color {
        dynamicColor(dark: 0xC0C0C0, light: 0x9A9082)
    }

    // MARK: - Race category palette
    // ピンの識別性を保ちつつ、Light テーマでは彩度を落とした深色版を使う。
    // Dark の高彩度ネオンはダーク地図上で映えるが、Light 地図ではコントラスト不足になるため
    // hex を切り替えて視認性を確保する。

    static var cat5K: Color           { dynamicColor(dark: 0x00E5FF, light: 0x0E7C92) }
    static var cat10K: Color          { dynamicColor(dark: 0x39FF7A, light: 0x2F7A3D) }
    static var catHalfMarathon: Color { dynamicColor(dark: 0xE8FF47, light: 0x7A8525) }
    static var catFullMarathon: Color { dynamicColor(dark: 0xFF3F8E, light: 0xB7305F) }
    static var catTrail: Color        { dynamicColor(dark: 0xC770FF, light: 0x6E40A0) }
    static var catUltra100K: Color    { dynamicColor(dark: 0xFF8A00, light: 0xB85F0A) }
    static var catUltraCustom: Color  { dynamicColor(dark: 0xFF8A00, light: 0xB85F0A) }

    // MARK: - Hex helpers

    /// 0xRRGGBB の整数からColorを構築
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >>  8) & 0xFF) / 255
        let b = Double( hex        & 0xFF) / 255
        self = Color(red: r, green: g, blue: b, opacity: opacity)
    }

    // MARK: - Dynamic builders (private)

    /// trait に応じて dark / light どちらかの hex を返す Color を構築する。
    /// SwiftUI / UIKit 双方の trait 変化で自動的に切替わる。
    /// macOS は本アプリのメインターゲットでないためダーク固定 (Map / iOS 機能限定)。
    fileprivate static func dynamicColor(dark: UInt32, light: UInt32) -> Color {
#if os(iOS)
        return Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(hex: dark)
                : UIColor(hex: light)
        })
#else
        return Color(hex: dark)
#endif
    }

    /// 現在テーマ × ユーザーが選んだ AccentChoice から hex を引き当てる。
    /// `keyPath` は `.hex` (メイン) か `.dimHex` (抑え) を渡す。
    fileprivate static func dynamicAccent(_ keyPath: KeyPath<AccentChoice, UInt32>) -> Color {
#if os(iOS)
        return Color(uiColor: UIColor { trait in
            let theme: AppTheme = trait.userInterfaceStyle == .dark ? .dark : .light
            let key = theme == .dark ? AccentChoice.storageKeyDark : AccentChoice.storageKeyLight
            let raw = UserDefaults.standard.string(forKey: key) ?? theme.defaultAccent.rawValue
            let choice = AccentChoice.resolve(raw, for: theme)
            return UIColor(hex: choice[keyPath: keyPath])
        })
#else
        // 非 iOS では現状ダーク固定でフォールバック。
        let raw = UserDefaults.standard.string(forKey: AccentChoice.storageKeyDark)
            ?? AppTheme.dark.defaultAccent.rawValue
        let choice = AccentChoice.resolve(raw, for: .dark)
        return Color(hex: choice[keyPath: keyPath])
#endif
    }
}

#if os(iOS)
extension UIColor {
    /// `Color(hex:)` の UIColor 版。dynamicProvider 内で利用する。
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255
        let g = CGFloat((hex >>  8) & 0xFF) / 255
        let b = CGFloat( hex        & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }
}
#endif
