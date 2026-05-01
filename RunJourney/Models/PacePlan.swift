import Foundation
import SwiftData

/// ペース計算機で保存するプラン。
/// 例: "サブ4 (フルマラソン)" → 42.195km を 4:00:00 で完走するための目標ペース。
@Model
final class PacePlan {
    var id: UUID = UUID()
    var name: String = ""
    var targetDistanceKm: Double = 42.195
    var targetTimeSec: Double = 14_400  // 4:00:00
    var notes: String? = nil
    var createdAt: Date = Date.now
    /// `PaceRaceType.rawValue`。旧データには無いので optional。
    /// 読込時に値があればそれを優先、なければ targetDistanceKm から推定。
    var raceTypeRaw: String? = nil

    init(
        id: UUID = UUID(),
        name: String = "",
        targetDistanceKm: Double = 42.195,
        targetTimeSec: Double = 14_400,
        notes: String? = nil,
        raceTypeRaw: String? = nil
    ) {
        self.id = id
        self.name = name
        self.targetDistanceKm = targetDistanceKm
        self.targetTimeSec = targetTimeSec
        self.notes = notes
        self.raceTypeRaw = raceTypeRaw
        self.createdAt = .now
    }

    /// 平均ペース (秒/km)
    var paceSecPerKm: Double {
        guard targetDistanceKm > 0 else { return 0 }
        return targetTimeSec / targetDistanceKm
    }
}
