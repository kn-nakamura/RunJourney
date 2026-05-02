import SwiftUI

/// Web版 marathon-record-app からテーマカラーを継承。
///
/// 設計トーン:
/// - ダークテーマ固定（Mapbox/Apple Mapsのダークマップと統一）
/// - 蛍光イエローグリーン (#E8FF47) をアクセントに
/// - カテゴリピンは Tailwind 400 系で統一（Web版と同色）
extension Color {

    // MARK: - Brand background palette
    static let bgPrimary    = Color(hex: 0x0A0A0F)  // ほぼ黒
    static let bgSecondary  = Color(hex: 0x13131A)  // カード背景
    static let bgTertiary   = Color(hex: 0x1C1C28)  // ホバー・アクティブ
    static let borderColor  = Color(hex: 0x2A2A3A)

    // MARK: - Text
    static let textPrimary  = Color(hex: 0xF0F0F0)
    static let textMuted    = Color(hex: 0x6B7280)

    // MARK: - Accent (蛍光イエローグリーン)
    static let accentPrimary = Color(hex: 0xE8FF47)
    static let accentDim     = Color(hex: 0xB8CC3A)

    // MARK: - Badges
    /// PB（Personal Best）バッジ色 — アクセントと同じ
    static let pbBadge = Color(hex: 0xE8FF47)
    /// SB（Season Best）バッジ色 — シルバー
    static let sbBadge = Color(hex: 0xC0C0C0)

    // MARK: - Race category palette (Neon / fluorescent)
    // ブランドアクセント (#E8FF47 蛍光イエロー) と並べて違和感のない高彩度ネオン系で
    // カテゴリごとに識別。Tailwind 400 系より明度・彩度を上げて夜間ダーク地図上で
    // 視認性を確保する。
    static let cat5K            = Color(hex: 0x00E5FF)  // neon cyan
    static let cat10K           = Color(hex: 0x39FF7A)  // neon green
    static let catHalfMarathon  = Color(hex: 0xE8FF47)  // accent yellow (= brand)
    static let catFullMarathon  = Color(hex: 0xFF3F8E)  // neon pink
    static let catTrail         = Color(hex: 0xC770FF)  // neon violet
    static let catUltra100K     = Color(hex: 0xFF8A00)  // neon orange
    static let catUltraCustom   = Color(hex: 0xFF8A00)  // neon orange (same family)

    // MARK: - Hex helpers

    /// 0xRRGGBB の整数からColorを構築
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >>  8) & 0xFF) / 255
        let b = Double( hex        & 0xFF) / 255
        self = Color(red: r, green: g, blue: b, opacity: opacity)
    }
}
