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
        case .ultra100k: return "Ultra 100K"
        case .custom:    return "Custom"
        }
    }

    /// 詳細表示用の長いラベル (Bebas Neue で UPPERCASE 表示する想定)
    var labelLong: String {
        switch self {
        case .fiveK:     return "5K"
        case .tenK:      return "10K"
        case .half:      return "Half Marathon"
        case .full:      return "Full Marathon"
        case .ultra100k: return "Ultra 100K"
        case .custom:    return "Custom"
        }
    }
}

/// 距離・ラップ間隔などの設定。
struct PaceRaceConfig: Hashable {
    let key: PaceRaceType
    let distanceKm: Double
    let lapIntervalKm: Double
}
