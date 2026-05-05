import SwiftUI

/// 共有カード/動画/画像の見た目をユーザーがシート上で調整するための設定モデル。
///
/// 設計方針:
/// - PaceShareSheet / ResultShareSheet / MapShareSheet で共通利用する。
/// - デフォルト値はアプリ全体の設定 (`AppTheme` / `AccentChoice`) から解決する。
///   ユーザーが共有シート上で変更しても、保存はせず一回限りで使う (Settings の好みを汚さない)。
/// - 共有カードは `Color.bgPrimary` 等の dynamic 色には依存させず、`ShareTheme` から
///   直接 hex 値を引き当てて静的に塗る。これは `ImageRenderer` がレンダリング時のみの
///   trait しか拾えず、ホスト側 ColorScheme と乖離するケースを避けるため。
struct ShareStyleConfig: Equatable {
    var theme: ShareTheme
    /// アクセント色。`palette` がテーマと一致しなければ resolve 時に自動補正される。
    var accent: AccentChoice
    var format: ShareFormat

    /// アプリ現状から既定値を組み立てる。
    static func defaultsFromAppSettings(systemColorScheme: ColorScheme) -> ShareStyleConfig {
        let appThemeRaw = UserDefaults.standard.string(forKey: AppTheme.userDefaultsKey)
            ?? AppTheme.dark.rawValue
        let theme = AppTheme.resolve(appThemeRaw)
        let resolved: ShareTheme
        switch theme {
        case .dark:   resolved = .dark
        case .light:  resolved = .light
        case .system: resolved = (systemColorScheme == .dark) ? .dark : .light
        }
        let accentKey = (resolved == .dark) ? AccentChoice.storageKeyDark : AccentChoice.storageKeyLight
        let accentRaw = UserDefaults.standard.string(forKey: accentKey)
            ?? resolved.appTheme.defaultAccent.rawValue
        let accent = AccentChoice.resolve(accentRaw, for: resolved.appTheme)
        return ShareStyleConfig(theme: resolved, accent: accent, format: .portrait)
    }
}

// MARK: - ShareTheme

/// 共有カード用の固定テーマ (system 追従はしない)。
/// アプリ全体テーマと同じ「夜のネオン」/「昼の自然光」トーンを適用する。
enum ShareTheme: String, CaseIterable, Identifiable {
    case dark
    case light

    var id: String { rawValue }
    var label: String {
        switch self {
        case .dark:  return "Dark"
        case .light: return "Light"
        }
    }
    var symbol: String {
        switch self {
        case .dark:  return "moon.fill"
        case .light: return "sun.max.fill"
        }
    }

    /// `AccentChoice.resolve(_:for:)` 用の対応 AppTheme を返す。
    var appTheme: AppTheme {
        switch self {
        case .dark:  return .dark
        case .light: return .light
        }
    }

    /// 静的に解決された背景・テキスト系カラーパレット。
    var palette: SharePalette {
        switch self {
        case .dark:
            return SharePalette(
                bgPrimary:   Color(hex: 0x0A0A0F),
                bgSecondary: Color(hex: 0x13131A),
                bgTertiary:  Color(hex: 0x1C1C28),
                textPrimary: Color(hex: 0xF0F0F0),
                textMuted:   Color(hex: 0x6B7280),
                border:      Color(hex: 0x2A2A3A),
                shadowAlpha: 0.42
            )
        case .light:
            return SharePalette(
                bgPrimary:   Color(hex: 0xF2EEE6),
                bgSecondary: Color(hex: 0xFBF8F2),
                bgTertiary:  Color(hex: 0xE5E0D6),
                textPrimary: Color(hex: 0x1B1814),
                textMuted:   Color(hex: 0x76705F),
                border:      Color(hex: 0xD6D0C4),
                shadowAlpha: 0.18
            )
        }
    }
}

struct SharePalette {
    let bgPrimary: Color
    let bgSecondary: Color
    let bgTertiary: Color
    let textPrimary: Color
    let textMuted: Color
    let border: Color
    let shadowAlpha: Double
}

// MARK: - ShareFormat

/// 出力サイズ (アスペクト含む)。SNS 各社の主要規格に合わせた 4 種を用意。
enum ShareFormat: String, CaseIterable, Identifiable {
    case portrait     // 1080×1920 — Instagram Story / TikTok / Reels
    case square       // 1080×1080 — Instagram feed
    case landscape    // 1920×1080 — YouTube / Twitter video
    case wide         // 1200×630  — OGP / X 横長カード

    var id: String { rawValue }

    var label: String {
        switch self {
        case .portrait:  return "Portrait"
        case .square:    return "Square"
        case .landscape: return "Landscape"
        case .wide:      return "Wide"
        }
    }
    var subtitle: String {
        switch self {
        case .portrait:  return "1080 × 1920 — Story"
        case .square:    return "1080 × 1080 — Feed"
        case .landscape: return "1920 × 1080 — Video"
        case .wide:      return "1200 × 630 — OGP"
        }
    }
    var symbol: String {
        switch self {
        case .portrait:  return "rectangle.portrait"
        case .square:    return "square"
        case .landscape: return "rectangle"
        case .wide:      return "rectangle.ratio.16.to.9"
        }
    }

    /// 出力ピクセル寸法。
    var pixelSize: CGSize {
        switch self {
        case .portrait:  return CGSize(width: 1080, height: 1920)
        case .square:    return CGSize(width: 1080, height: 1080)
        case .landscape: return CGSize(width: 1920, height: 1080)
        case .wide:      return CGSize(width: 1200, height: 630)
        }
    }

    /// `ImageRenderer` の論理サイズ。pixelSize の 1/2 を使い、scale=2 で実寸を出す。
    var logicalSize: CGSize {
        let p = pixelSize
        return CGSize(width: p.width / 2, height: p.height / 2)
    }

    /// レイアウト用ヘルパ: 縦長か。
    var isPortrait: Bool { pixelSize.height > pixelSize.width }
    /// レイアウト用ヘルパ: 横長か (= 上下に高さの余裕がない)。
    var isWide: Bool {
        let p = pixelSize
        return p.width / p.height >= 1.6
    }
    /// 正方形か。
    var isSquare: Bool { pixelSize.width == pixelSize.height }
}
