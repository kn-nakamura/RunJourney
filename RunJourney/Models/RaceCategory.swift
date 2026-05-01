import Foundation
import SwiftUI

enum RaceCategory: String, Codable, CaseIterable, Identifiable {
    case fiveK = "5K"
    case tenK = "10K"
    case halfMarathon = "HalfMarathon"
    case fullMarathon = "FullMarathon"
    case trail = "Trail"
    case ultra100K = "Ultra100K"
    case ultraCustom = "UltraCustom"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fiveK: return "5km"
        case .tenK: return "10km"
        case .halfMarathon: return "ハーフマラソン"
        case .fullMarathon: return "フルマラソン"
        case .trail: return "トレイル"
        case .ultra100K: return "100km"
        case .ultraCustom: return "ウルトラ"
        }
    }

    var defaultDistanceKm: Double? {
        switch self {
        case .fiveK: return 5
        case .tenK: return 10
        case .halfMarathon: return 21.0975
        case .fullMarathon: return 42.195
        case .ultra100K: return 100
        case .trail, .ultraCustom: return nil
        }
    }

    /// Web版 marathon-record-app と同じTailwind 400系カラー。
    /// 実際のhex値は `Color+RunJourney.swift` を参照。
    var pinColor: Color {
        switch self {
        case .fiveK:         return .cat5K           // blue-400  #60A5FA
        case .tenK:          return .cat10K          // emerald-400 #34D399
        case .halfMarathon:  return .catHalfMarathon // amber-400 #FBBF24
        case .fullMarathon:  return .catFullMarathon // red-400   #F87171
        case .trail:         return .catTrail        // violet-400 #A78BFA
        case .ultra100K:     return .catUltra100K    // orange-400 #FB923C
        case .ultraCustom:   return .catUltraCustom
        }
    }

    var symbolName: String {
        switch self {
        case .trail: return "mountain.2.fill"
        case .ultra100K, .ultraCustom: return "infinity"
        default: return "figure.run"
        }
    }
}
