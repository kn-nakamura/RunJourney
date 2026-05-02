import Foundation

/// 大会(Race)のロゴ画像を端末ローカル (Documents/race-logos) に保存する。
///
/// 設計メモ:
/// - 保存パスは Documents 直下の相対パス (`race-logos/{uuid}.jpg`) を返す。
///   絶対 URL は再インストール毎に変わるため、Race.logoURL には相対パスを格納する。
/// - 将来 CloudKit 同期に乗せた場合、画像本体は CKAsset として送る前提で
///   本ストアはローカルキャッシュ層として使い続けられる。
enum RaceLogoStore {

    static let directoryName = "race-logos"

    /// `Documents/race-logos/` ディレクトリ。なければ作成する。
    static func directoryURL() throws -> URL {
        let docs = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = docs.appendingPathComponent(directoryName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// 画像データを保存し、Documents 起点の相対パスを返す。
    /// - Parameters:
    ///   - data: 画像バイト列
    ///   - raceID: ファイル名衝突回避用に使用
    ///   - ext: ファイル拡張子（既定 jpg）
    @discardableResult
    static func save(_ data: Data, for raceID: UUID, ext: String = "jpg") throws -> String {
        let dir = try directoryURL()
        let filename = "\(raceID.uuidString).\(ext)"
        let url = dir.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return "\(directoryName)/\(filename)"
    }

    /// 相対パス (`race-logos/xxx.jpg`) から絶対 URL へ解決。フルURLや http(s) もそのまま返す。
    static func url(for relativeOrAbsolute: String?) -> URL? {
        guard let value = relativeOrAbsolute, !value.isEmpty else { return nil }
        if let abs = URL(string: value), let scheme = abs.scheme, !scheme.isEmpty {
            return abs
        }
        guard let docs = try? FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else { return nil }
        return docs.appendingPathComponent(value)
    }

    /// 保存済み画像を削除。相対パス指定。失敗は無視する。
    static func delete(_ relativePath: String?) {
        guard let path = relativePath, !path.isEmpty,
              let url = url(for: path),
              url.isFileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
