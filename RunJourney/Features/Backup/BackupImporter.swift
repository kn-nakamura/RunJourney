import Foundation
import SwiftData

// MARK: - Public types

struct BackupImportSummary {
    var racesAdded: Int = 0
    var resultsAdded: Int = 0
    var plansAdded: Int = 0
    var racesSkipped: Int = 0
    var resultsSkipped: Int = 0
    var plansSkipped: Int = 0
    var errors: [String] = []

    var totalSkipped: Int { racesSkipped + resultsSkipped + plansSkipped }
}

enum BackupImportError: LocalizedError {
    case unrecognizedFormat
    case decodingFailed(String)
    case fileAccessDenied

    var errorDescription: String? {
        switch self {
        case .unrecognizedFormat:
            return "Unrecognized file format. Expected a RunJourney backup or Supabase JSON export."
        case .decodingFailed(let detail):
            return "Import failed: \(detail)"
        case .fileAccessDenied:
            return "File access was denied. Please try again."
        }
    }
}

// MARK: - Importer

enum BackupImporter {
    @discardableResult
    static func importData(
        from data: Data,
        into context: ModelContext,
        existingRaces: [Race],
        existingResults: [RaceResult],
        existingPlans: [PacePlan]
    ) throws -> BackupImportSummary {
        let format = try BackupFormat.detect(data: data)

        var existingRaceIDs = Set(existingRaces.map(\.id))
        var existingResultIDs = Set(existingResults.map(\.id))
        var existingPlanIDs = Set(existingPlans.map(\.id))

        switch format {
        case .nativeRunJourney:
            return try importNative(
                data: data, into: context,
                existingRaceIDs: &existingRaceIDs,
                existingResultIDs: &existingResultIDs,
                existingPlanIDs: &existingPlanIDs
            )
        case .supabaseMarathonRecord:
            return try importSupabase(
                data: data, into: context,
                existingRaceIDs: &existingRaceIDs,
                existingResultIDs: &existingResultIDs,
                existingPlanIDs: &existingPlanIDs
            )
        }
    }
}

// MARK: - Native format

private extension BackupImporter {
    static func importNative(
        data: Data,
        into context: ModelContext,
        existingRaceIDs: inout Set<UUID>,
        existingResultIDs: inout Set<UUID>,
        existingPlanIDs: inout Set<UUID>
    ) throws -> BackupImportSummary {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let file: BackupFile
        do {
            file = try decoder.decode(BackupFile.self, from: data)
        } catch {
            throw BackupImportError.decodingFailed(error.localizedDescription)
        }

        var summary = BackupImportSummary()

        for backupRace in file.races {
            if existingRaceIDs.contains(backupRace.id) {
                summary.racesSkipped += 1
                summary.resultsSkipped += backupRace.results.count
                continue
            }

            let race = Race(
                id: backupRace.id,
                name: backupRace.name,
                category: RaceCategory(rawValue: backupRace.category) ?? .fullMarathon,
                distanceKm: backupRace.distanceKm,
                address: backupRace.address,
                city: backupRace.city,
                country: backupRace.country,
                lat: backupRace.lat,
                lng: backupRace.lng,
                websiteURL: backupRace.websiteURL,
                logoURL: backupRace.logoURL
            )
            race.createdAt = backupRace.createdAt
            context.insert(race)
            existingRaceIDs.insert(backupRace.id)
            summary.racesAdded += 1

            for br in backupRace.results {
                if existingResultIDs.contains(br.id) {
                    summary.resultsSkipped += 1
                    continue
                }
                let result = RaceResult(id: br.id, race: race, raceDate: br.raceDate, finishTimeSec: br.finishTimeSec)
                result.isDNF = br.isDNF
                result.isDNS = br.isDNS
                result.isPB = br.isPB
                result.isSB = br.isSB
                result.weatherTempC = br.weatherTempC
                result.weatherDescription = br.weatherDescription.flatMap { WeatherDescription(rawValue: $0) }
                result.weatherCode = br.weatherCode
                result.condition = br.condition.flatMap { Condition(rawValue: $0) }
                result.bibNumber = br.bibNumber
                result.ageGroupPlace = br.ageGroupPlace
                result.overallPlace = br.overallPlace
                result.totalFinishers = br.totalFinishers
                result.comment = br.comment
                result.lapData = br.lapData
                result.trackPoints = br.trackPoints
                result.summary = br.summary
                result.linkedPacePlanId = br.linkedPacePlanId
                result.createdAt = br.createdAt
                context.insert(result)
                existingResultIDs.insert(br.id)
                summary.resultsAdded += 1
            }
        }

        for bp in file.pacePlans {
            if existingPlanIDs.contains(bp.id) {
                summary.plansSkipped += 1
                continue
            }
            let plan = PacePlan(
                id: bp.id,
                name: bp.name,
                targetDistanceKm: bp.targetDistanceKm,
                targetTimeSec: bp.targetTimeSec,
                notes: bp.notes,
                raceTypeRaw: bp.raceTypeRaw
            )
            plan.createdAt = bp.createdAt
            context.insert(plan)
            existingPlanIDs.insert(bp.id)
            summary.plansAdded += 1
        }

        do {
            try context.save()
        } catch {
            throw BackupImportError.decodingFailed("Save failed: \(error.localizedDescription)")
        }

        return summary
    }
}

// MARK: - Supabase format (snake_case, JSONSerialization based)

private extension BackupImporter {
    static let supabaseDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static func parseDate(_ raw: Any?) -> Date? {
        guard let s = raw as? String else { return nil }
        return supabaseDateFormatter.date(from: s)
            ?? iso8601Formatter.date(from: s)
            ?? ISO8601DateFormatter().date(from: s)
    }

    static func parseUUID(_ raw: Any?) -> UUID? {
        guard let s = raw as? String else { return nil }
        return UUID(uuidString: s)
    }

    static func decodeJSONB<T: Decodable>(_ raw: Any?, as type: T.Type) -> T? {
        guard let raw = raw else { return nil }
        // raw is already a parsed JSON object/array from JSONSerialization
        guard let reEncoded = try? JSONSerialization.data(withJSONObject: raw) else { return nil }
        return try? JSONDecoder().decode(type, from: reEncoded)
    }

    static func supabaseDistanceKm(for raceType: String?) -> Double {
        switch raceType {
        case "5k": return 5.0
        case "10k": return 10.0
        case "half": return 21.0975
        case "full": return 42.195
        case "ultra100k": return 100.0
        default: return 42.195
        }
    }

    static func importSupabase(
        data: Data,
        into context: ModelContext,
        existingRaceIDs: inout Set<UUID>,
        existingResultIDs: inout Set<UUID>,
        existingPlanIDs: inout Set<UUID>
    ) throws -> BackupImportSummary {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BackupImportError.decodingFailed("Invalid JSON structure")
        }

        var summary = BackupImportSummary()
        var insertedRacesByStringID: [String: Race] = [:]

        // --- races ---
        let racesArray = json["races"] as? [[String: Any]] ?? []
        for r in racesArray {
            guard let id = parseUUID(r["id"]) else {
                summary.errors.append("races: skipped row with invalid id")
                continue
            }
            if existingRaceIDs.contains(id) {
                summary.racesSkipped += 1
                insertedRacesByStringID[r["id"] as? String ?? ""] = nil
                continue
            }
            let category = RaceCategory(rawValue: r["category"] as? String ?? "") ?? .fullMarathon
            let race = Race(
                id: id,
                name: r["name"] as? String ?? "",
                category: category,
                distanceKm: r["distance_km"] as? Double,
                address: r["address"] as? String,
                city: r["city"] as? String,
                country: r["country"] as? String ?? "Japan",
                lat: r["lat"] as? Double ?? 0,
                lng: r["lng"] as? Double ?? 0,
                websiteURL: r["website_url"] as? String,
                logoURL: r["logo_url"] as? String
            )
            if let created = parseDate(r["created_at"]) { race.createdAt = created }
            context.insert(race)
            existingRaceIDs.insert(id)
            insertedRacesByStringID[r["id"] as? String ?? ""] = race
            summary.racesAdded += 1
        }

        // --- race_results ---
        let resultsArray = json["race_results"] as? [[String: Any]] ?? []
        for r in resultsArray {
            guard let id = parseUUID(r["id"]) else {
                summary.errors.append("race_results: skipped row with invalid id")
                continue
            }
            if existingResultIDs.contains(id) {
                summary.resultsSkipped += 1
                continue
            }
            let raceDate = parseDate(r["race_date"]) ?? Date.now
            let result = RaceResult(id: id, race: nil, raceDate: raceDate)

            if let sec = r["finish_time_sec"] as? Int {
                result.finishTimeSec = Double(sec)
            }
            result.isDNF = r["is_dnf"] as? Bool ?? false
            result.isDNS = r["is_dns"] as? Bool ?? false
            result.isPB = r["is_pb"] as? Bool ?? false
            result.isSB = r["is_sb"] as? Bool ?? false
            result.weatherTempC = r["weather_temp_c"] as? Double
            result.weatherDescription = (r["weather_desc"] as? String).flatMap { WeatherDescription(rawValue: $0) }
            result.weatherCode = r["weather_code"] as? Int
            result.condition = (r["condition"] as? String).flatMap { Condition(rawValue: $0) }
            result.bibNumber = r["bib_number"] as? String
            result.ageGroupPlace = r["age_group_place"] as? Int
            result.overallPlace = r["overall_place"] as? Int
            result.totalFinishers = r["total_finishers"] as? Int
            result.comment = r["comment"] as? String

            if let laps = decodeJSONB(r["lap_data"], as: [LapData].self) {
                result.lapData = laps
            } else if r["lap_data"] != nil {
                summary.errors.append("race_results \(id): lap_data could not be decoded")
            }
            if let pts = decodeJSONB(r["trackpoint_data"], as: [TrackPoint].self) {
                result.trackPoints = pts
            } else if r["trackpoint_data"] != nil {
                summary.errors.append("race_results \(id): trackpoint_data could not be decoded")
            }
            result.summary = decodeJSONB(r["summary_stats"], as: SummaryStats.self)
            if let created = parseDate(r["created_at"]) { result.createdAt = created }

            // Link to parent race
            if let raceIdStr = r["race_id"] as? String,
               let parentRace = insertedRacesByStringID[raceIdStr] {
                result.race = parentRace
            }

            context.insert(result)
            existingResultIDs.insert(id)
            summary.resultsAdded += 1
        }

        // --- pace_plans ---
        let plansArray = json["pace_plans"] as? [[String: Any]] ?? []
        for p in plansArray {
            guard let id = parseUUID(p["id"]) else {
                summary.errors.append("pace_plans: skipped row with invalid id")
                continue
            }
            if existingPlanIDs.contains(id) {
                summary.plansSkipped += 1
                continue
            }
            let raceType = p["race_type"] as? String
            let plan = PacePlan(
                id: id,
                name: p["name"] as? String ?? "",
                targetDistanceKm: supabaseDistanceKm(for: raceType),
                targetTimeSec: Double(p["goal_time_seconds"] as? Int ?? 14400),
                notes: nil,
                raceTypeRaw: raceType
            )
            if let created = parseDate(p["created_at"]) { plan.createdAt = created }
            context.insert(plan)
            existingPlanIDs.insert(id)
            summary.plansAdded += 1
        }

        do {
            try context.save()
        } catch {
            throw BackupImportError.decodingFailed("Save failed: \(error.localizedDescription)")
        }

        return summary
    }
}
