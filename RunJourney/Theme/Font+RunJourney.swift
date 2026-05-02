import SwiftUI
import UIKit

// MARK: - Typography Tokens
//
// Web 版 marathon-record-app の Tailwind 規約に揃えたタイポグラフィ・トークン。
// - Display (Bebas Neue): 必ず UPPERCASE + tracking。テキスト見出し専用。
// - Body    (DM Sans):    通常文章 / UI ラベル。
// - Code    (JetBrains Mono): 数値（ペース・タイム・距離等）はすべてここ。
//
// 主 API は `View.appText(_:)`。`Font` 値が必要な箇所（Charts AxisValueLabel 等）
// は `Font.appFont(_:)` を使う（uppercase/tracking は適用されない）。
//
// サイズは Tailwind スケール (12/14/16/18/20/24/30/36) に基づく。
// `Font.custom(_:fixedSize:)` で Dynamic Type には乗せず Web と視覚一致を優先。

enum AppTextToken {
    // Display (Bebas Neue) — uppercase + tracking baked in
    case displayXs, displaySm, displayMd, displayLg, displayXl, displayHero
    // Body (DM Sans)
    case bodyXs, bodySm, bodyBase, bodyMd, bodyLg
    case bodyXsBold, bodySmBold, bodyBaseBold, bodyMdBold
    // Code (JetBrains Mono) — numerals
    case codeXxs, codeXs, codeSm, codeBase, codeMd, codeLg, codeXl, codeHero
    case codeXxsBold, codeXsBold, codeSmBold, codeBaseBold, codeMdBold, codeLgBold
    // Badge / eyebrow
    case badge, badgeNumeric, eyebrow
}

struct AppTextSpec {
    let psName: String
    let size: CGFloat
    let kerning: CGFloat
    let uppercase: Bool
}

extension AppTextToken {
    var spec: AppTextSpec {
        switch self {
        // Display
        case .displayXs:    return .init(psName: "BebasNeue-Regular", size: 14, kerning: 1.4, uppercase: true)
        case .displaySm:    return .init(psName: "BebasNeue-Regular", size: 18, kerning: 1.4, uppercase: true)
        case .displayMd:    return .init(psName: "BebasNeue-Regular", size: 24, kerning: 1.2, uppercase: true)
        case .displayLg:    return .init(psName: "BebasNeue-Regular", size: 30, kerning: 1.0, uppercase: true)
        case .displayXl:    return .init(psName: "BebasNeue-Regular", size: 36, kerning: 0.9, uppercase: true)
        case .displayHero:  return .init(psName: "BebasNeue-Regular", size: 56, kerning: 0.6, uppercase: true)
        // Body
        case .bodyXs:       return .init(psName: "DMSans-Regular",     size: 12, kerning: 0,   uppercase: false)
        case .bodySm:       return .init(psName: "DMSans-Regular",     size: 14, kerning: 0,   uppercase: false)
        case .bodyBase:     return .init(psName: "DMSans-Regular",     size: 16, kerning: 0,   uppercase: false)
        case .bodyMd:       return .init(psName: "DMSans-Medium",      size: 18, kerning: 0,   uppercase: false)
        case .bodyLg:       return .init(psName: "DMSans-Medium",      size: 20, kerning: 0,   uppercase: false)
        case .bodyXsBold:   return .init(psName: "DMSans-Bold",        size: 12, kerning: 0,   uppercase: false)
        case .bodySmBold:   return .init(psName: "DMSans-Bold",        size: 14, kerning: 0,   uppercase: false)
        case .bodyBaseBold: return .init(psName: "DMSans-Bold",        size: 16, kerning: 0,   uppercase: false)
        case .bodyMdBold:   return .init(psName: "DMSans-Bold",        size: 18, kerning: 0,   uppercase: false)
        // Code
        case .codeXxs:      return .init(psName: "JetBrainsMono-Regular", size: 10, kerning: 0, uppercase: false)
        case .codeXs:       return .init(psName: "JetBrainsMono-Regular", size: 12, kerning: 0, uppercase: false)
        case .codeSm:       return .init(psName: "JetBrainsMono-Regular", size: 14, kerning: 0, uppercase: false)
        case .codeBase:     return .init(psName: "JetBrainsMono-Regular", size: 16, kerning: 0, uppercase: false)
        case .codeMd:       return .init(psName: "JetBrainsMono-Medium",  size: 18, kerning: 0, uppercase: false)
        case .codeLg:       return .init(psName: "JetBrainsMono-Medium",  size: 24, kerning: 0, uppercase: false)
        case .codeXl:       return .init(psName: "JetBrainsMono-Medium",  size: 36, kerning: 0, uppercase: false)
        case .codeHero:     return .init(psName: "JetBrainsMono-Regular", size: 96, kerning: 0, uppercase: false)
        case .codeXxsBold:  return .init(psName: "JetBrainsMono-Bold",    size: 10, kerning: 0, uppercase: false)
        case .codeXsBold:   return .init(psName: "JetBrainsMono-Bold",    size: 12, kerning: 0, uppercase: false)
        case .codeSmBold:   return .init(psName: "JetBrainsMono-Bold",    size: 14, kerning: 0, uppercase: false)
        case .codeBaseBold: return .init(psName: "JetBrainsMono-Bold",    size: 16, kerning: 0, uppercase: false)
        case .codeMdBold:   return .init(psName: "JetBrainsMono-Bold",    size: 18, kerning: 0, uppercase: false)
        case .codeLgBold:   return .init(psName: "JetBrainsMono-Bold",    size: 24, kerning: 0, uppercase: false)
        // Badge / eyebrow
        case .badge:        return .init(psName: "DMSans-Bold",           size: 11, kerning: 1.5, uppercase: true)
        case .badgeNumeric: return .init(psName: "JetBrainsMono-Bold",    size: 11, kerning: 0.8, uppercase: true)
        case .eyebrow:      return .init(psName: "DMSans-Bold",           size: 10, kerning: 2.5, uppercase: true)
        }
    }
}

// MARK: - View modifier (primary API)

private struct AppTextStyle: ViewModifier {
    let spec: AppTextSpec
    func body(content: Content) -> some View {
        content
            .font(.custom(spec.psName, fixedSize: spec.size))
            .kerning(spec.kerning)
            .textCase(spec.uppercase ? .uppercase : nil)
    }
}

extension View {
    func appText(_ token: AppTextToken) -> some View {
        modifier(AppTextStyle(spec: token.spec))
    }
}

// MARK: - Font value (for Charts API and other Font-only call sites)

extension Font {
    static func appFont(_ token: AppTextToken) -> Font {
        let spec = token.spec
        return .custom(spec.psName, fixedSize: spec.size)
    }
}

// MARK: - DEBUG font registration check

#if DEBUG
@MainActor
private let _appFontRegistrationCheck: Void = {
    let names = [
        "BebasNeue-Regular",
        "DMSans-Regular", "DMSans-Medium", "DMSans-Bold",
        "JetBrainsMono-Regular", "JetBrainsMono-Medium", "JetBrainsMono-Bold",
    ]
    for n in names {
        assert(UIFont(name: n, size: 12) != nil, "Font not registered (check Info.plist UIAppFonts and Resources/Fonts/): \(n)")
    }
}()
#endif

