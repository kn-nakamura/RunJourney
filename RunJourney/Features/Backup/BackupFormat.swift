import Foundation

// MARK: - Native RunJourney backup format (camelCase, nested results inside race)

struct BackupFile: Codable {
    var version: Int = 1
    var app: String = "RunJourney"
    var exportedAt: Date
    var races: [BackupRace]
    var pacePlans: [BackupPacePlan]
}

struct BackupRace: Codable {
    var id: UUID
    var name: String
    var category: String
    var distanceKm: Double?
    var address: String?
    var city: String?
    var country: String
    var lat: Double
    var lng: Double
    var websiteURL: String?
    var logoURL: String?
    var createdAt: Date
    var results: [BackupRaceResult]
}

struct BackupRaceResult: Codable {
    var id: UUID
    var raceDate: Date
    var finishTimeSec: Double?
    var isDNF: Bool
    var isDNS: Bool
    var isPB: Bool
    var isSB: Bool
    var weatherTempC: Double?
    var weatherDescription: String?
    var weatherCode: Int?
    var condition: String?
    var bibNumber: String?
    var ageGroupPlace: Int?
    var overallPlace: Int?
    var totalFinishers: Int?
    var comment: String?
    var lapData: [LapData]
    var trackPoints: [TrackPoint]
    var summary: SummaryStats?
    var linkedPacePlanId: UUID?
    var createdAt: Date
}

struct BackupPacePlan: Codable {
    var id: UUID
    var name: String
    var targetDistanceKm: Double
    var targetTimeSec: Double
    var notes: String?
    var raceTypeRaw: String?
    var createdAt: Date
}

// MARK: - Format detection

enum BackupSourceFormat {
    case nativeRunJourney
    case supabaseMarathonRecord
}

enum BackupFormat {
    static func detect(data: Data) throws -> BackupSourceFormat {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BackupImportError.decodingFailed("Not a valid JSON object")
        }
        let keys = Set(json.keys)
        if keys.contains("version") && keys.contains("races") && keys.contains("pacePlans") {
            return .nativeRunJourney
        }
        if keys.contains("races") && keys.contains("race_results") {
            return .supabaseMarathonRecord
        }
        throw BackupImportError.unrecognizedFormat
    }
}
