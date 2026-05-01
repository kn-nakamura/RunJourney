import Foundation
import SwiftData
import CoreLocation

/// ファイル拡張子を見て適切なパーサーへ振り分け、結果を SwiftData に保存する。
enum ActivityImporter {

    /// 対応拡張子（小文字）
    static let supportedExtensions: Set<String> = ["gpx", "tcx"]
    // FIT は SwiftPM で FitDataProtocol を導入する Phase 3.5+ で追加

    /// ファイルURLからパース。security-scoped resource を扱う。
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

        switch ext {
        case "gpx": return try GPXParser.parse(data: data)
        case "tcx": return try TCXParser.parse(data: data)
        default: throw ImportError.unsupportedFormat(ext)
        }
    }

    /// パース結果から Race と RaceResult を作成し ModelContext に挿入する。
    /// - Parameters:
    ///   - activity: パース済データ
    ///   - context: SwiftData ModelContext
    ///   - fileName: ファイル名（レース名のデフォルトに使用）
    /// - Returns: 作成した (Race, RaceResult)
    @discardableResult
    static func saveAsNewRace(
        _ activity: ParsedActivity,
        context: ModelContext,
        fileName: String? = nil
    ) -> (race: Race, result: RaceResult) {
        let raceName: String = {
            if let fn = fileName {
                let base = (fn as NSString).deletingPathExtension
                if !base.isEmpty { return base }
            }
            if let date = activity.startDate {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd"
                return "アクティビティ \(f.string(from: date))"
            }
            return "新規レース"
        }()

        let coord = activity.startCoordinate
            ?? CLLocationCoordinate2D(latitude: 35.6909, longitude: 139.6917)
        let race = Race(
            name: raceName,
            category: activity.estimatedCategory,
            distanceKm: activity.totalDistanceKm,
            lat: coord.latitude,
            lng: coord.longitude
        )

        let result = RaceResult(
            race: race,
            raceDate: activity.startDate ?? .now,
            finishTimeSec: activity.finishTimeSec
        )
        result.lapData = activity.laps
        // 表示用にサンプリングしてから保存（CloudKit/メモリ節約）
        result.trackPoints = ActivityMath.sampleTrackPoints(activity.trackPoints)
        result.summary = activity.summary

        context.insert(race)
        context.insert(result)

        return (race, result)
    }
}
