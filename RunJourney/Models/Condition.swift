import Foundation

enum Condition: String, Codable, CaseIterable, Identifiable {
    case great
    case good
    case average
    case poor
    case bad

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .great: return "Great"
        case .good: return "Good"
        case .average: return "Average"
        case .poor: return "Poor"
        case .bad: return "Bad"
        }
    }

    var symbolName: String {
        switch self {
        case .great: return "face.smiling.inverse"
        case .good: return "face.smiling"
        case .average: return "face.dashed"
        case .poor: return "face.dashed.fill"
        case .bad: return "minus.circle.fill"
        }
    }
}
