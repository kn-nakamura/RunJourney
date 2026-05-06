import Foundation

/// データ保存先の選択肢。初回起動時にユーザーが選び、UserDefaults に永続化する。
///
/// `.local`  — 端末ローカルのみ（SwiftData の通常 store）
/// `.iCloud` — CloudKit private DB に同期（同 Apple ID 間でデバイス横断）
enum StorageLocation: String, Codable, CaseIterable {
    case local
    case iCloud

    static let userDefaultsKey = "storageLocation"
    static let chosenFlagKey   = "storageLocationChosen"

    /// SwiftUI 側で `Text(_ resource:)` 経由で表示するための localizable 値。
    /// `String` で返すと `Text(String)` 経路が localization を完全にスキップするため、
    /// 文字列カタログを使わずに英語のまま固定されてしまう。
    var displayName: LocalizedStringResource {
        switch self {
        case .local:  return "On This Device"
        case .iCloud: return "iCloud Sync"
        }
    }

    var systemImage: String {
        switch self {
        case .local:  return "iphone"
        case .iCloud: return "icloud"
        }
    }

    var detail: LocalizedStringResource {
        switch self {
        case .local:
            return "Records stay on this device only. Fastest, most private."
        case .iCloud:
            return "Records sync across your iPhone, iPad and Mac via iCloud (same Apple ID)."
        }
    }
}
