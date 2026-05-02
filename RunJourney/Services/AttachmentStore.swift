import Foundation
import UniformTypeIdentifiers

/// Race / RaceResult に紐付く添付ファイル（PDF・画像）のローカルストア。
///
/// 設計メモ:
/// - 保存先は `Documents/attachments/{ownerID}/{attachmentID}.{ext}`
///   （Race.id または RaceResult.id を ownerID として使う）。
/// - SwiftData 側には Documents 起点の相対パス（`attachments/.../xxx.pdf`）だけを保存。
///   絶対 URL は再インストール毎に変わるため格納しない。
/// - iCloud（CloudKit）同期した際にバイナリ本体は同期されない。これは将来 `Data` プロパティを
///   model に持たせて CKAsset 経由で同期する別タスクで対応する。
///
/// `RaceLogoStore` は単一ロゴ用に既存。本ストアは複数添付向けの一般版。
enum AttachmentStore {

    static let directoryName = "attachments"

    /// `Documents/attachments/{ownerID}/` を返す。なければ作成する。
    static func directoryURL(ownerID: UUID) throws -> URL {
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

    /// 任意の `Data` を保存し、Documents 起点の相対パスを返す。
    @discardableResult
    static func save(
        _ data: Data,
        ownerID: UUID,
        attachmentID: UUID,
        ext: String
    ) throws -> String {
        let dir = try directoryURL(ownerID: ownerID)
        let safeExt = ext.isEmpty ? "bin" : ext
        let filename = "\(attachmentID.uuidString).\(safeExt)"
        let url = dir.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return "\(directoryName)/\(ownerID.uuidString)/\(filename)"
    }

    /// `.fileImporter` から渡された security-scoped URL を取り込んでサンドボックス内に複製する。
    /// - Returns: (相対パス, 拡張子, バイト数, mime type)
    static func ingestPickedFile(
        at sourceURL: URL,
        ownerID: UUID,
        attachmentID: UUID
    ) throws -> (relativePath: String, ext: String, byteSize: Int, mimeType: String?) {
        let scoped = sourceURL.startAccessingSecurityScopedResource()
        defer { if scoped { sourceURL.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: sourceURL)
        let ext = sourceURL.pathExtension.isEmpty ? "bin" : sourceURL.pathExtension.lowercased()
        let mime = UTType(filenameExtension: ext)?.preferredMIMEType
        let rel = try save(data, ownerID: ownerID, attachmentID: attachmentID, ext: ext)
        return (rel, ext, data.count, mime)
    }

    /// 相対パスから絶対 URL を解決。空 / nil は nil を返す。
    static func url(for relativePath: String?) -> URL? {
        guard let path = relativePath, !path.isEmpty else { return nil }
        guard let docs = try? FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else { return nil }
        return docs.appendingPathComponent(path)
    }

    /// 単一ファイル削除。失敗は無視。
    static func delete(_ relativePath: String?) {
        guard let url = url(for: relativePath), url.isFileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// オーナー（Race / Result）配下のディレクトリを丸ごと削除。
    /// Race / Result 削除時のクリーンアップ用。
    static func deleteAll(ownerID: UUID) {
        guard let dir = try? directoryURL(ownerID: ownerID) else { return }
        try? FileManager.default.removeItem(at: dir)
    }
}
