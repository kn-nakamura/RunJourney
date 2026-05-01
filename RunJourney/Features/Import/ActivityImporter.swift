import Foundation
import SwiftData
import CoreLocation

/// ファイル拡張子を見て適切なパーサーへ振り分け、結果を SwiftData に保存する。
enum ActivityImporter {

    /// 対応拡張子（小文字）
    static let supportedExtensions: Set<String> = ["gpx", "tcx", "fit", "zip"]

    /// ファイルURLからパース。security-scoped resource を扱う。
    /// `.zip` の場合は中の最初の .fit / .gpx / .tcx を抽出してそれぞれのパーサーへ委譲する。
    static func parse(url: URL) throws -> ParsedActivity {
        let ext = url.pathExtension.lowercased()
        guard supportedExtensions.contains(ext) else {
            throw ImportError.unsupportedFormat(ext)
        }

        let didStart = url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ImportError.fileAccessDenied
        }

        return try parse(data: data, ext: ext)
    }

    /// 既にメモリにあるデータを拡張子ヒント付きでパース。zip 再帰用に internal で使う。
    private static func parse(data: Data, ext: String) throws -> ParsedActivity {
        switch ext {
        case "gpx": return try GPXParser.parse(data: data)
        case "tcx": return try TCXParser.parse(data: data)
        case "fit": return try FITParser.parse(data: data)
        case "zip":
            // 優先順位: .fit > .tcx > .gpx
            let entries = try ZipReader.extractAll(from: data)
            for preferred in ["fit", "tcx", "gpx"] {
                if let entry = entries.first(where: { ($0.name as NSString).pathExtension.lowercased() == preferred }) {
                    return try parse(data: entry.data, ext: preferred)
                }
            }
            throw ImportError.parseFailed("ZIP: アクティビティファイル(.fit/.tcx/.gpx)が含まれていません — 含まれるエントリ: \(entries.map(\.name).joined(separator: ", "))")
        default:
            throw ImportError.unsupportedFormat(ext)
        }
    }

    /// パース結果から **新しい大会(Race) + 結果(RaceResult)** を作成して保存。
    @discardableResult
    static func saveAsNewRace(
        _ activity: ParsedActivity,
        context: ModelContext,
        raceName: String? = nil,
        fileName: String? = nil
    ) -> (race: Race, result: RaceResult) {
        let name = raceName ?? defaultRaceName(activity: activity, fileName: fileName)
        let coord = activity.startCoordinate
            ?? CLLocationCoordinate2D(latitude: 35.6909, longitude: 139.6917)
        let race = Race(
            name: name,
            category: activity.estimatedCategory,
            distanceKm: activity.totalDistanceKm,
            lat: coord.latitude,
            lng: coord.longitude
        )
        context.insert(race)
        let result = makeResult(activity: activity, race: race)
        context.insert(result)
        return (race, result)
    }

    /// **既存の大会(Race)に結果だけ追加**して保存。Webアプリの「同じ大会の年別結果」フローに対応。
    @discardableResult
    static func appendResult(
        _ activity: ParsedActivity,
        to race: Race,
        context: ModelContext
    ) -> RaceResult {
        let result = makeResult(activity: activity, race: race)
        context.insert(result)
        return result
    }

    // MARK: - Helpers

    private static func makeResult(activity: ParsedActivity, race: Race) -> RaceResult {
        let result = RaceResult(
            race: race,
            raceDate: activity.startDate ?? .now,
            finishTimeSec: activity.finishTimeSec
        )
        result.lapData = activity.laps
        result.trackPoints = ActivityMath.sampleTrackPoints(activity.trackPoints)
        result.summary = activity.summary
        return result
    }

    /// 大会名のデフォルト値: ファイル名 → 日付ベース → "新規大会" の順で組み立てる。
    static func defaultRaceName(activity: ParsedActivity, fileName: String?) -> String {
        if let fn = fileName {
            let base = (fn as NSString).deletingPathExtension
            // Garmin export の "12345678901_ACTIVITY" のような数字+ACTIVITY は人間に優しい名前にする
            if !base.isEmpty,
               !(base.hasSuffix("_ACTIVITY") || base.allSatisfy({ $0.isNumber })) {
                return base
            }
        }
        if let date = activity.startDate {
            let f = DateFormatter()
            f.locale = Locale(identifier: "ja_JP")
            f.dateFormat = "yyyy/MM/dd"
            return "\(activity.estimatedCategory.displayName) (\(f.string(from: date)))"
        }
        return "新しい大会"
    }
}
