import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Exporter

enum BackupExporter {
    static func makeBackupData(races: [Race], plans: [PacePlan]) throws -> Data {
        let backupRaces = races.map { race -> BackupRace in
            let backupResults = (race.results ?? []).map { r -> BackupRaceResult in
                BackupRaceResult(
                    id: r.id,
                    raceDate: r.raceDate,
                    finishTimeSec: r.finishTimeSec,
                    isDNF: r.isDNF,
                    isDNS: r.isDNS,
                    isPB: r.isPB,
                    isSB: r.isSB,
                    weatherTempC: r.weatherTempC,
                    weatherDescription: r.weatherDescription?.rawValue,
                    weatherCode: r.weatherCode,
                    condition: r.condition?.rawValue,
                    bibNumber: r.bibNumber,
                    ageGroupPlace: r.ageGroupPlace,
                    overallPlace: r.overallPlace,
                    totalFinishers: r.totalFinishers,
                    comment: r.comment,
                    lapData: r.lapData,
                    trackPoints: r.trackPoints,
                    summary: r.summary,
                    linkedPacePlanId: r.linkedPacePlanId,
                    createdAt: r.createdAt
                )
            }
            return BackupRace(
                id: race.id,
                name: race.name,
                category: race.category.rawValue,
                distanceKm: race.distanceKm,
                address: race.address,
                city: race.city,
                country: race.country,
                lat: race.lat,
                lng: race.lng,
                websiteURL: race.websiteURL,
                logoURL: race.logoURL,
                createdAt: race.createdAt,
                results: backupResults
            )
        }

        let backupPlans = plans.map { p -> BackupPacePlan in
            BackupPacePlan(
                id: p.id,
                name: p.name,
                targetDistanceKm: p.targetDistanceKm,
                targetTimeSec: p.targetTimeSec,
                notes: p.notes,
                raceTypeRaw: p.raceTypeRaw,
                createdAt: p.createdAt
            )
        }

        let file = BackupFile(
            exportedAt: .now,
            races: backupRaces,
            pacePlans: backupPlans
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(file)
    }
}

// MARK: - FileDocument wrapper for .fileExporter

struct BackupFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let fileData = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = fileData
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
