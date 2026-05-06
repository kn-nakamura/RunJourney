import Foundation

/// 大会(Race)のロゴ画像を扱うヘルパ。
///
/// 設計メモ:
/// - 新規ロゴはバイナリを `Race.logoData` に直接入れる。CloudKit 同期 ON のとき
///   1MB 超は自動的に CKAsset として転送される（SwiftData が裏で持ち替える）。
/// - 旧データはバイナリ本体が `Documents/race-logos/{raceID}.{ext}` にあり
///   `Race.logoURL` に相対パスが入っている。読み出しは `fileURL(for:)` を経由して
///   フォールバック解決する。
/// - `logoURL` が "https://..." の絶対 URL のときはそのまま返す（外部ロゴへの参照）。
/// - `AsyncImage` 等の URL 必須 API のために、必要時に `tmp/` へ materialize する。
enum RaceLogoStore {

    /// CloudKit CKAsset の上限。`AttachmentStore.maxBinarySize` と同じく安全側 50MB。
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
                return "Logo too large (\(actualStr)). Maximum is \(limitStr)."
            }
        }
    }

    static func validate(_ data: Data) throws {
        guard data.count <= maxBinarySize else { throw SaveError.tooLarge(actual: data.count) }
    }

    // MARK: - Read

    /// ロゴ画像にアクセスする URL を返す。
    /// 1. `logoURL` が http(s) 絶対 URL ならそれを返す（外部参照）
    /// 2. `logoData` があれば `tmp/race-logo-cache/{raceID}.{ext}` に書き出して返す
    /// 3. 旧 `logoURL` 相対パスが Documents に存在すればそれを返す
    /// 4. どれにも該当しなければ nil
    static func fileURL(for race: Race) -> URL? {
        if let raw = race.logoURL,
           let abs = URL(string: raw),
           let scheme = abs.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            return abs
        }
        if let data = race.logoData {
            return materialize(data: data, raceID: race.id, ext: extensionHint(race: race))
        }
        if let url = legacyURL(for: race.logoURL),
           FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        return nil
    }

    /// 旧コード互換用。新規コードでは `fileURL(for:)` を使うこと。
    static func url(for relativeOrAbsolute: String?) -> URL? {
        guard let value = relativeOrAbsolute, !value.isEmpty else { return nil }
        if let abs = URL(string: value),
           let scheme = abs.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            return abs
        }
        return legacyURL(for: value)
    }

    // MARK: - Delete

    /// Race のローカル成果物（tmp キャッシュ・旧 Documents ファイル）を掃除する。
    /// `Race` モデルの削除自体は呼び出し側で行う。
    static func deleteLocalArtifacts(for race: Race) {
        purgeCache(for: race.id)
        delete(race.logoURL)
    }

    /// 旧 Documents ファイル単体を削除。失敗は無視。
    static func delete(_ relativePath: String?) {
        guard let path = relativePath, !path.isEmpty,
              let url = legacyURL(for: path),
              url.isFileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Private

    private static func materialize(data: Data, raceID: UUID, ext: String) -> URL? {
        let safeExt = ext.isEmpty ? "jpg" : ext
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("race-logo-cache", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let url = dir.appendingPathComponent("\(raceID.uuidString).\(safeExt)")
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

    private static func purgeCache(for raceID: UUID) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("race-logo-cache", isDirectory: true)
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else { return }
        let prefix = raceID.uuidString
        for entry in entries where entry.hasPrefix(prefix) {
            try? FileManager.default.removeItem(at: dir.appendingPathComponent(entry))
        }
    }

    private static func extensionHint(race: Race) -> String {
        if let raw = race.logoURL {
            let ext = (raw as NSString).pathExtension
            if !ext.isEmpty { return ext.lowercased() }
        }
        return "jpg"
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
