import Foundation

/// レース全体の集計指標。TCX/FITから自動生成され `RaceResult.summary` に入る。
struct SummaryStats: Codable, Hashable {
    var avgPaceSecPerKm: Double?
    var totalDistanceM: Double?
    var totalTimeSec: Double?
    var avgHeartRate: Int?
    var maxHeartRate: Int?
    var elevationGainM: Double?
    var elevationLossM: Double?
    var minAltitudeM: Double?
    var maxAltitudeM: Double?
    var totalCalories: Double?
    var avgCadence: Int?
    var maxCadence: Int?
    var avgPowerW: Double?
    var maxPowerW: Double?
    var avgTemperatureC: Double?

    init(
        avgPaceSecPerKm: Double? = nil,
        totalDistanceM: Double? = nil,
        totalTimeSec: Double? = nil,
        avgHeartRate: Int? = nil,
        maxHeartRate: Int? = nil,
        elevationGainM: Double? = nil,
        elevationLossM: Double? = nil,
        minAltitudeM: Double? = nil,
        maxAltitudeM: Double? = nil,
        totalCalories: Double? = nil,
        avgCadence: Int? = nil,
        maxCadence: Int? = nil,
        avgPowerW: Double? = nil,
        maxPowerW: Double? = nil,
        avgTemperatureC: Double? = nil
    ) {
        self.avgPaceSecPerKm = avgPaceSecPerKm
        self.totalDistanceM = totalDistanceM
        self.totalTimeSec = totalTimeSec
        self.avgHeartRate = avgHeartRate
        self.maxHeartRate = maxHeartRate
        self.elevationGainM = elevationGainM
        self.elevationLossM = elevationLossM
        self.minAltitudeM = minAltitudeM
        self.maxAltitudeM = maxAltitudeM
        self.totalCalories = totalCalories
        self.avgCadence = avgCadence
        self.maxCadence = maxCadence
        self.avgPowerW = avgPowerW
        self.maxPowerW = maxPowerW
        self.avgTemperatureC = avgTemperatureC
    }
}
