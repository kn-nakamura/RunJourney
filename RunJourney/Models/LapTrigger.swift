import Foundation

/// マラソン/ランニングのラップ区切り発生理由（TCX/FIT準拠）
enum LapTrigger: String, Codable {
    case manual = "Manual"
    case distance = "Distance"
    case time = "Time"
    case location = "Location"
    case heartRate = "HeartRate"
    case fitnessEquipment = "FitnessEquipment"
    case sessionEnd = "SessionEnd"
}
