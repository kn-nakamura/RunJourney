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

    // MARK: - Race category palette (Tailwind 400)
    static let cat5K            = Color(hex: 0x60A5FA)  // blue-400
    static let cat10K           = Color(hex: 0x34D399)  // emerald-400
    static let catHalfMarathon  = Color(hex: 0xFBBF24)  // amber-400
    static let catFullMarathon  = Color(hex: 0xF87171)  // red-400
    static let catTrail         = Color(hex: 0xA78BFA)  // violet-400
    static let catUltra100K     = Color(hex: 0xFB923C)  // orange-400
    static let catUltraCustom   = Color(hex: 0xFB923C)  // orange-400 (same family)

    // MARK: - Hex helpers

    /// 0xRRGGBB の整数からColorを構築
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >>  8) & 0xFF) / 255
        let b = Double( hex        & 0xFF) / 255
        self = Color(red: r, green: g, blue: b, opacity: opacity)
    }
}
