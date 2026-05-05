import SwiftUI

/// アプリ全体のカラーテーマ。Settings → Appearance で切替可能。
///
/// 設計トーン:
/// - Dark = 夜のネオン (現行ブランド: 蛍光イエロー × ほぼ黒)
/// - Light = 昼の自然光 (パーチメント基調 × 自然素材アクセント)
/// - System = iOS の外観設定 (Dark / Light) に追従
enum AppTheme: String, CaseIterable, Identifiable {
    case dark
    case light
    case system

    var id: String { rawValue }
    var label: String {
        switch self {
        case .dark:   return "Dark"
        case .light:  return "Light"
        case .system: return "System"
        }
    }
    var symbol: String {
        switch self {
        case .dark:   return "moon.fill"
        case .light:  return "sun.max.fill"
        case .system: return "circle.lefthalf.filled"
        }
    }
    /// `nil` を返した場合は SwiftUI / UIKit のシステム外観に追従する。
    var colorScheme: ColorScheme? {
        switch self {
        case .dark:   return .dark
        case .light:  return .light
        case .system: return nil
        }
    }
    var defaultAccent: AccentChoice {
        switch self {
        case .dark:   return .neonYellow
        case .light:  return .sunYellow
        case .system: return .neonYellow
        }
    }

    static let userDefaultsKey = "appTheme"

    /// `@AppStorage` から読み出した raw 値を安全にデコード。未知値は dark にフォールバック。
    static func resolve(_ raw: String) -> AppTheme {
        AppTheme(rawValue: raw) ?? .dark
    }
}

/// アクセントカラー (ブランドの第一カラー) のユーザー選択肢。
///
/// ダーク用は既存ピンカテゴリと色相を共有するネオン系 5 色。
/// ライト用は自然光・自然素材に寄せたアーシー系 + 暖色イエロー。
/// テーマ毎に独立した `@AppStorage` キーで保存し、テーマを切替えても各テーマで前回選んだ色が維持される。
enum AccentChoice: String, CaseIterable, Identifiable {
    // Dark theme — neon
    case neonYellow
    case neonCyan
    case neonPink
    case neonGreen
    case neonOrange
    // Light theme — natural / earthy + warm yellow
    case sunYellow
    case mossGreen
    case terracotta
    case oliveGold
    case slateBlue
    case dustyCoral

    var id: String { rawValue }

    /// この色が属するテーマ。Settings の swatch grid フィルタに使用。
    var palette: AppTheme {
        switch self {
        case .neonYellow, .neonCyan, .neonPink, .neonGreen, .neonOrange:
            return .dark
        case .sunYellow, .mossGreen, .terracotta, .oliveGold, .slateBlue, .dustyCoral:
            return .light
        }
    }

    var label: String {
        switch self {
        case .neonYellow:  return "Neon Yellow"
        case .neonCyan:    return "Neon Cyan"
        case .neonPink:    return "Neon Pink"
        case .neonGreen:   return "Neon Green"
        case .neonOrange:  return "Neon Orange"
        case .sunYellow:   return "Sun"
        case .mossGreen:   return "Moss"
        case .terracotta:  return "Terracotta"
        case .oliveGold:   return "Olive Gold"
        case .slateBlue:   return "Slate"
        case .dustyCoral:  return "Coral"
        }
    }

    /// メインアクセント色 (0xRRGGBB)。
    var hex: UInt32 {
        switch self {
        case .neonYellow:  return 0xE8FF47
        case .neonCyan:    return 0x00E5FF
        case .neonPink:    return 0xFF3F8E
        case .neonGreen:   return 0x39FF7A
        case .neonOrange:  return 0xFF8A00
        case .sunYellow:   return 0xE0B83C
        case .mossGreen:   return 0x6B8E3D
        case .terracotta:  return 0xB05A3C
        case .oliveGold:   return 0xA08530
        case .slateBlue:   return 0x547186
        case .dustyCoral:  return 0xC25F4A
        }
    }

    /// 抑え色 (badge dim 等)。手調整値で品質担保。
    var dimHex: UInt32 {
        switch self {
        case .neonYellow:  return 0xB8CC3A
        case .neonCyan:    return 0x008FA0
        case .neonPink:    return 0xB02A66
        case .neonGreen:   return 0x2BB358
        case .neonOrange:  return 0xB35F00
        case .sunYellow:   return 0x9C7E1F
        case .mossGreen:   return 0x4E6A2C
        case .terracotta:  return 0x82412B
        case .oliveGold:   return 0x755F1F
        case .slateBlue:   return 0x3A4F5C
        case .dustyCoral:  return 0x8E4537
        }
    }

    static let storageKeyDark  = "accentChoice.dark"
    static let storageKeyLight = "accentChoice.light"

    /// 現在テーマと raw 値から AccentChoice を解決。
    /// - 値が無効 / テーマと不整合なら、そのテーマの default accent にフォールバック。
    /// - `.system` は実 palette を持たないため、呼び出し側で実際の colorScheme を解決してから渡す。
    static func resolve(_ raw: String, for theme: AppTheme) -> AccentChoice {
        if let parsed = AccentChoice(rawValue: raw), parsed.palette == theme {
            return parsed
        }
        return theme.defaultAccent
    }

    /// 与えられたテーマの選択肢のみを宣言順で返す。`.system` は空配列。
    static func options(for theme: AppTheme) -> [AccentChoice] {
        AccentChoice.allCases.filter { $0.palette == theme }
    }
}
