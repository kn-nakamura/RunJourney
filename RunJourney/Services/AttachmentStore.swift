import Foundation
import UniformTypeIdentifiers

/// Race / RaceResult に紐付く添付ファイル（PDF・画像）の保存ヘルパ。
///
/// 設計メモ:
/// - 新規保存はバイナリを `Attachment.binaryData` に直接入れる。CloudKit 同期 ON のとき
///   1MB 超は自動的に CKAsset として転送される（SwiftData が裏で持ち替える）。
/// - 旧データはバイナリ本体が `Documents/attachments/{ownerID}/{attachmentID}.{ext}`
///   にあり `relativePath` だけがモデルに保存されている。読み出しは
///   `fileURL(for:)` を経由してフォールバックする。
/// - QuickLook / AsyncImage 等の URL 必須 API のために、必要時に `tmp/` へ
///   materialize する。揮発キャッシュなので再起動で消えても次の `fileURL(for:)`
///   で再生成される。
enum AttachmentStore {

    static let directoryName = "attachments"

    /// CloudKit CKAsset の上限は 50MB / asset、レコード合計は ~200MB。
    /// 安全側に振って 50MB を超えるバイナリは保存させない。
    static let maxBinarySize: Int = 50 * 1024 * 1024

    enum SaveError: LocalizedError {
        case tooLarge(actual: Int)

        var errorDescription: String? {
            switch self {
            case .tooLarge(let actual):
                let formatter = ByteCountFormatter()
                formatter.countStyle = .file
                let actualStr = formatter.string(fromByteCount: Int64(actual))
                let limitStr  = formatter.string(fromByteCount: Int64(maxBinarySize))
                return "File too large to attach (\(actualStr)). Maximum is \(limitStr)."
            }
        }
    }

    // MARK: - Save (model-backed)

    /// `.fileImporter` から渡された security-scoped URL を読み出してバイト列を返す。
    /// 呼び出し側はこの bytes を `Attachment.binaryData` に格納する。
    /// - Returns: (bytes, ext, byteSize, mimeType)
    static func readPickedFile(at sourceURL: URL) throws -> (data: Data, ext: String, byteSize: Int, mimeType: String?) {
        let scoped = sourceURL.startAccessingSecurityScopedResource()
        defer { if scoped { sourceURL.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: sourceURL)
        guard data.count <= maxBinarySize else { throw SaveError.tooLarge(actual: data.count) }
        let ext  = sourceURL.pathExtension.isEmpty ? "bin" : sourceURL.pathExtension.lowercased()
        let mime = UTType(filenameExtension: ext)?.preferredMIMEType
        return (data, ext, data.count, mime)
    }

    /// 任意の `Data` をサイズ検証する。`Attachment.binaryData` への代入前に呼ぶ。
    static func validate(_ data: Data) throws {
        guard data.count <= maxBinarySize else { throw SaveError.tooLarge(actual: data.count) }
    }

    // MARK: - Read (URL resolution with legacy fallback)

    /// 添付バイナリにアクセスする URL を返す。
    /// 1. `binaryData` があれば `tmp/attachment-cache/{id}.{ext}` に書き出して返す
    /// 2. 旧 `relativePath` の Documents ファイルが存在すればそれを返す
    /// 3. どちらも無ければ nil（CloudKit 同期がまだ来ていない / ファイル消失）
    static func fileURL(for attachment: Attachment) -> URL? {
        if let data = attachment.binaryData {
            return materialize(data: data, id: attachment.id, ext: extensionHint(for: attachment))
        }
        if let url = legacyURL(for: attachment.relativePath), FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        return nil
    }

    /// 旧コード互換用: `relativePath` 文字列から絶対 URL を解決する。
    /// 新規コードでは `fileURL(for:)` を使うこと。
    static func url(for relativePath: String?) -> URL? {
        legacyURL(for: relativePath)
    }

    // MARK: - Delete

    /// 指定 attachment のローカルキャッシュおよび旧 Documents ファイルを掃除する。
    /// モデルそのものの削除は呼び出し側で `modelContext.delete(_:)` する。
    static func deleteLocalArtifacts(for attachment: Attachment) {
        purgeCache(for: attachment.id)
        delete(attachment.relativePath)
    }

    /// 単一の旧 Documents ファイルを削除。失敗は無視。
    static func delete(_ relativePath: String?) {
        guard let url = legacyURL(for: relativePath), url.isFileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// オーナー（Race / Result）配下の旧ディレクトリを丸ごと削除。
    /// Race / Result 削除時のクリーンアップ用。
    static func deleteAll(ownerID: UUID) {
        if let dir = try? legacyDirectoryURL(ownerID: ownerID) {
            try? FileManager.default.removeItem(at: dir)
        }
    }

    // MARK: - Private helpers

    private static func materialize(data: Data, id: UUID, ext: String) -> URL? {
        let safeExt = ext.isEmpty ? "bin" : ext
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("attachment-cache", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let url = dir.appendingPathComponent("\(id.uuidString).\(safeExt)")
        // 既存と中身が同じなら書き直さない（QuickLook 中の URL 差し替え抑止）
        if let existing = try? Data(contentsOf: url), existing == data {
            return url
        }
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private static func purgeCache(for id: UUID) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("attachment-cache", isDirectory: true)
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else { return }
        let prefix = id.uuidString
        for entry in entries where entry.hasPrefix(prefix) {
            try? FileManager.default.removeItem(at: dir.appendingPathComponent(entry))
        }
    }

    private static func extensionHint(for attachment: Attachment) -> String {
        if let original = attachment.originalFilename {
            let ext = (original as NSString).pathExtension
            if !ext.isEmpty { return ext.lowercased() }
        }
        if let mime = attachment.mimeType,
           let utType = UTType(mimeType: mime),
           let ext = utType.preferredFilenameExtension {
            return ext
        }
        switch attachment.kind {
        case .pdf:   return "pdf"
        case .image: return "jpg"
        default:     return "bin"
        }
    }

    private static func legacyDirectoryURL(ownerID: UUID) throws -> URL {
        let docs = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = docs
            .appendingPathComponent(directoryName, isDirectory: true)
            .appendingPathComponent(ownerID.uuidString, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private static func legacyURL(for relativePath: String?) -> URL? {
        guard let path = relativePath, !path.isEmpty else { return nil }
        guard let docs = try? FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else { return nil }
        return docs.appendingPathComponent(path)
    }
}
