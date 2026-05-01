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
        case .great: return "絶好調"
        case .good: return "良い"
        case .average: return "普通"
        case .poor: return "悪い"
        case .bad: return "最悪"
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
