import Foundation
import SwiftData

/// Race / RaceResult に紐付けられる多態の添付項目。
///
/// **設計メモ**:
/// - 1Password 風の「+ Add another」を実現するため、種別ごとに型を分けず
///   単一 `@Model` ＋ `kind` enum + 各 payload プロパティ optional の多態とする。
/// - CloudKit 制約に従い `@Attribute(.unique)` 不使用、全プロパティに default、
///   relationship には inverse を設定。
/// - `race` / `result` のうち**どちらか一方**だけが set される。プロトコル型 relationship が
///   使えないため2本に分ける（CloudKit 制約）。
@Model
final class Attachment {
    var id: UUID = UUID()
    var kind: AttachmentKind = AttachmentKind.text
    /// ユーザーが任意に書き換えできる表示ラベル。
    var label: String = ""

    // 種別ごとに片方が埋まる polymorphic payload
    var textValue: String? = nil          // .text
    var urlString: String? = nil          // .url
    /// .pdf / .image: バイナリ本体。CloudKit に乗ると 1MB 超は CKAsset として転送される。
    /// 旧データは `relativePath` 経由の Documents ファイルに本体があり、ここは nil の場合がある。
    /// 読み出しは `AttachmentStore.fileURL(for:)` を経由すること（旧データはそのままフォールバック）。
    @Attribute(.externalStorage)
    var binaryData: Data? = nil
    /// 旧スキーマ互換: Documents 起点の相対パス。新規保存では使わず `binaryData` のみ書く。
    var relativePath: String? = nil
    var originalFilename: String? = nil   // .pdf / .image
    var mimeType: String? = nil           // .pdf / .image
    var byteSize: Int? = nil              // .pdf / .image
    var phAssetLocalID: String? = nil     // .photoAsset

    /// ユーザーが行入れ替えしたときの順序保持用。
    var sortOrder: Int = 0
    var createdAt: Date = Date.now

    var race: Race? = nil
    var result: RaceResult? = nil

    init(
        kind: AttachmentKind = .text,
        label: String = "",
        race: Race? = nil,
        result: RaceResult? = nil
    ) {
        self.id = UUID()
        self.kind = kind
        self.label = label
        self.race = race
        self.result = result
        self.createdAt = .now
    }
}
