import Foundation
import CoreLocation

/// TCX/GPX/FIT パースの中間結果。
/// `ActivityImporter` がこれを `Race` / `RaceResult` に変換する。
struct ParsedActivity {
    var trackPoints: [TrackPoint]
    var laps: [LapData]
    var summary: SummaryStats
    var startDate: Date?
    var endDate: Date?
    var finishTimeSec: Double?
    var startCoordinate: CLLocationCoordinate2D?
    var endCoordinate: CLLocationCoordinate2D?

    /// 総距離(km)から `RaceCategory` を推定する。
    var estimatedCategory: RaceCategory {
        let km = (trackPoints.last?.distanceM ?? 0) / 1000.0
        switch km {
        case ..<7: return .fiveK
        case ..<15: return .tenK
        case ..<30: return .halfMarathon
        case ..<50: return .fullMarathon
        case ..<99: return .ultraCustom
        default: return .ultra100K
        }
    }

    /// 総距離(km)
    var totalDistanceKm: Double {
        (trackPoints.last?.distanceM ?? 0) / 1000.0
    }
}

enum ImportError: LocalizedError {
    case unsupportedFormat(String)
    case parseFailed(String)
    case noTrackPoints
    case fileAccessDenied

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let ext): return "Unsupported file format: .\(ext)"
        case .parseFailed(let detail): return "Parse failed: \(detail)"
        case .noTrackPoints: return "File has no GPS track"
        case .fileAccessDenied: return "Could not access the file"
        }
    }
}
