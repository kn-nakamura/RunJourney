import Foundation

/// 1ラップ分の集計指標。TCX/GPX/FITから抽出される。
/// `RaceResult` に Codable JSON として埋め込まれ、@Model にはしない（1結果あたり数十件で十分軽量）。
struct LapData: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var lapIndex: Int
    var distanceM: Double
    var timeSec: Double
    var paceSecPerKm: Double

    var triggerMethod: LapTrigger?
    var avgHeartRate: Int?
    var maxHeartRate: Int?
    var elevationGainM: Double?
    var elevationLossM: Double?
    var avgCadence: Int?
    var maxCadence: Int?
    var avgPowerW: Double?
    var maxPowerW: Double?
    var avgTemperatureC: Double?
    var calories: Double?

    init(
        lapIndex: Int,
        distanceM: Double,
        timeSec: Double,
        paceSecPerKm: Double,
        triggerMethod: LapTrigger? = nil,
        avgHeartRate: Int? = nil,
        maxHeartRate: Int? = nil,
        elevationGainM: Double? = nil,
        elevationLossM: Double? = nil,
        avgCadence: Int? = nil,
        maxCadence: Int? = nil,
        avgPowerW: Double? = nil,
        maxPowerW: Double? = nil,
        avgTemperatureC: Double? = nil,
        calories: Double? = nil
    ) {
        self.lapIndex = lapIndex
        self.distanceM = distanceM
        self.timeSec = timeSec
        self.paceSecPerKm = paceSecPerKm
        self.triggerMethod = triggerMethod
        self.avgHeartRate = avgHeartRate
        self.maxHeartRate = maxHeartRate
        self.elevationGainM = elevationGainM
        self.elevationLossM = elevationLossM
        self.avgCadence = avgCadence
        self.maxCadence = maxCadence
        self.avgPowerW = avgPowerW
        self.maxPowerW = maxPowerW
        self.avgTemperatureC = avgTemperatureC
        self.calories = calories
    }
}
