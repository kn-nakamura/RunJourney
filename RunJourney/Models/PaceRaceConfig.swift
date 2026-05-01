import Foundation

/// ペース計算機で扱う距離プリセット種別。
/// (Web 版 marathon-record-app の `PaceRaceType` に対応)
enum PaceRaceType: String, CaseIterable, Identifiable, Hashable {
    case fiveK = "5k"
    case tenK = "10k"
    case half
    case full
    case ultra100k
    case custom

    var id: String { rawValue }

    /// セグメント Picker 用の短いラベル
    var label: String {
        switch self {
        case .fiveK:     return "5K"
        case .tenK:      return "10K"
        case .half:      return "Half"
        case .full:      return "Full"
        case .ultra100k: return "Ultra"
        case .custom:    return "Custom"
        }
    }

    /// 詳細表示用の日本語ラベル
    var labelJa: String {
        switch self {
        case .fiveK:     return "5キロ"
        case .tenK:      return "10キロ"
        case .half:      return "ハーフマラソン"
        case .full:      return "フルマラソン"
        case .ultra100k: return "ウルトラ100K"
        case .custom:    return "カスタム"
        }
    }
}

/// 距離・ラップ間隔などの設定。
struct PaceRaceConfig: Hashable {
    let key: PaceRaceType
    let distanceKm: Double
    let lapIntervalKm: Double
}
