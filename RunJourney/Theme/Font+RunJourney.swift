import SwiftUI

/// Web版 marathon-record-app のタイポグラフィを継承:
/// - Display: Bebas Neue (タイム表示・大見出し)
/// - Body:    DM Sans (本文・UI)
/// - Mono:    JetBrains Mono (ペース・数値)
///
/// `Font.custom(_:size:)` は `UIAppFonts` 登録済みフォントの
/// PostScript名を引数に取る。
extension Font {

    // MARK: - Display (Bebas Neue) — 高さを稼ぐ大見出し用
    static func display(_ size: CGFloat) -> Font {
        .custom("BebasNeue-Regular", size: size)
    }

    /// Title-XL: ヒーロータイム表示など (例: 03:45:23)
    static let displayHero = Font.custom("BebasNeue-Regular", size: 56)
    /// Title-L: 主要見出し
    static let displayLarge = Font.custom("BebasNeue-Regular", size: 36)
    /// Title-M: セクション見出し
    static let displayMedium = Font.custom("BebasNeue-Regular", size: 24)

    // MARK: - Body (DM Sans)
    static func body(_ size: CGFloat, weight: BodyWeight = .regular) -> Font {
        .custom(weight.postscriptName, size: size)
    }

    enum BodyWeight {
        case regular, medium, bold
        var postscriptName: String {
            switch self {
            case .regular: return "DMSans-Regular"
            case .medium:  return "DMSans-Medium"
            case .bold:    return "DMSans-Bold"
            }
        }
    }

    // MARK: - Mono (JetBrains Mono) — 数値表示
    static func mono(_ size: CGFloat, bold: Bool = false) -> Font {
        .custom(bold ? "JetBrainsMono-Bold" : "JetBrainsMono-Regular", size: size)
    }

    /// ペース・タイムなど一覧で揃えたい数値
    static let monoBody = Font.custom("JetBrainsMono-Regular", size: 15)
    /// PB/SBバッジ・小さな数値ラベル
    static let monoCaption = Font.custom("JetBrainsMono-Bold", size: 11)
}
