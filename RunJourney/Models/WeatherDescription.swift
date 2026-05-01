import Foundation

enum WeatherDescription: String, Codable, CaseIterable, Identifiable {
    case sunny
    case cloudy
    case rainy
    case windy
    case snowy

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sunny: return "晴れ"
        case .cloudy: return "曇り"
        case .rainy: return "雨"
        case .windy: return "風強い"
        case .snowy: return "雪"
        }
    }

    var symbolName: String {
        switch self {
        case .sunny: return "sun.max.fill"
        case .cloudy: return "cloud.fill"
        case .rainy: return "cloud.rain.fill"
        case .windy: return "wind"
        case .snowy: return "snowflake"
        }
    }

    /// WMO weather code (https://open-meteo.com/en/docs) → category mapping
    static func from(wmoCode code: Int) -> WeatherDescription {
        switch code {
        case 0, 1: return .sunny
        case 2, 3: return .cloudy
        case 45, 48: return .cloudy
        case 51...67, 80...82: return .rainy
        case 71...77, 85, 86: return .snowy
        case 95...99: return .rainy
        default: return .cloudy
        }
    }
}
