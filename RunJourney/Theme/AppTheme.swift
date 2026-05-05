import SwiftUI

/// アプリ全体のカラーテーマ。Settings → Appearance で切替可能。
///
/// 設計トーン:
/// - Dark = 夜のネオン (現行ブランド: 蛍光イエロー × ほぼ黒)
/// - Light = 昼の自然光 (パーチメント基調 × 自然素材アクセント)
enum AppTheme: String, CaseIterable, Identifiable {
    case dark
    case light

    var id: String { rawValue }
    var label: String { self == .dark ? "Dark" : "Light" }
    var symbol: String { self == .dark ? "moon.fill" : "sun.max.fill" }
    var colorScheme: ColorScheme { self == .dark ? .dark : .light }
    var defaultAccent: AccentChoice { self == .dark ? .neonYellow : .mossGreen }

    static let userDefaultsKey = "appTheme"

    /// `@AppStorage` から読み出した raw 値を安全にデコード。未知値は dark にフォールバック。
    static func resolve(_ raw: String) -> AppTheme {
        AppTheme(rawValue: raw) ?? .dark
    }
}

/// アクセントカラー (ブランドの第一カラー) のユーザー選択肢。
///
/// ダーク用は既存ピンカテゴリと色相を共有するネオン系 5 色。
/// ライト用は自然光・自然素材に寄せたアーシー系 5 色。
/// テーマ毎に独立した `@AppStorage` キーで保存し、テーマを切替えても各テーマで前回選んだ色が維持される。
enum AccentChoice: String, CaseIterable, Identifiable {
    // Dark theme — neon
    case neonYellow
    case neonCyan
    case neonPink
    case neonGreen
    case neonOrange
    // Light theme — natural / earthy
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
        case .mossGreen, .terracotta, .oliveGold, .slateBlue, .dustyCoral:
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
    static func resolve(_ raw: String, for theme: AppTheme) -> AccentChoice {
        if let parsed = AccentChoice(rawValue: raw), parsed.palette == theme {
            return parsed
        }
        return theme.defaultAccent
    }

    /// 与えられたテーマの選択肢のみを宣言順で返す。
    static func options(for theme: AppTheme) -> [AccentChoice] {
        AccentChoice.allCases.filter { $0.palette == theme }
    }
}
