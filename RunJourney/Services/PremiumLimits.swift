import Foundation

/// 無料プランの上限と Premium gate 判定をまとめた静的定数。
///
/// 既存データが上限を超えていた場合 (Premium → 無料へのダウングレード等) は
/// 既存レコードの閲覧・編集・削除はそのまま許可し、**新規追加だけを止める** UX に
/// 統一する（破壊的に消えると驚くため）。
enum PremiumLimits {

    /// 無料プランで保持できる Race の最大件数（追加を止める閾値）。
    /// 既存ユーザーが既に超えている場合は閲覧・編集は維持する。
    static let freeRaceLimit: Int = 5

    /// 無料プランで保持できる Result の最大件数（全 Race 合計）。
    static let freeResultLimit: Int = 20

    /// 添付バイナリ (PDF / 画像) を新規保存できるか。テキスト・URL 添付は無料でも可。
    /// `Attachment.binaryData` を埋める種類の添付（`.pdf` / `.image`）が gate 対象。
    static let binaryAttachmentRequiresPremium: Bool = true

    /// Race ロゴ画像 (`Race.logoData`) も同様に Premium 対象。
    /// URL 指定の `logoURL` は無料でも使える。
    static let logoImageRequiresPremium: Bool = true

    // MARK: - Helpers

    /// 「現在の Race 数」を渡して、新規 Race を追加できるかを返す。
    static func canAddRace(currentCount: Int, hasPremium: Bool) -> Bool {
        hasPremium || currentCount < freeRaceLimit
    }

    /// 「現在の Result 総数」を渡して、新規 Result を追加できるかを返す。
    static func canAddResult(currentCount: Int, hasPremium: Bool) -> Bool {
        hasPremium || currentCount < freeResultLimit
    }
}
