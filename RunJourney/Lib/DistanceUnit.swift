import Foundation
import SwiftUI

/// アプリ全体で共有する距離単位 (km / mi)。
/// 内部ストレージは常に km。表示・入力レイヤーだけがこの enum を介して変換する。
enum DistanceUnit: String, CaseIterable, Identifiable {
    case km
    case mi

    var id: String { rawValue }

    /// 短縮ラベル (TextField 末尾などに使う)
    var label: String { self == .km ? "km" : "mi" }

    /// "/km" or "/mi" — pace の suffix
    var perLabel: String { "/\(label)" }

    /// 速度の単位ラベル ("km/h" / "mph")
    var speedLabel: String { self == .km ? "km/h" : "mph" }
}

/// 1 マイル = 1.609344 km (公式定義)
let kmPerMile: Double = 1.609344

extension Double {
    /// 内部 km 値 → ユーザー表示単位の値
    func displayed(in u: DistanceUnit) -> Double {
        u == .km ? self : self / kmPerMile
    }

    /// ユーザー入力 (表示単位) → 内部 km 値
    func toKm(from u: DistanceUnit) -> Double {
        u == .km ? self : self * kmPerMile
    }
}

/// `@AppStorage("distanceUnit")` の文字列を enum に解決するヘルパー。
/// 不正値はすべて `.km` にフォールバック。
extension DistanceUnit {
    static func resolve(_ raw: String) -> DistanceUnit {
        DistanceUnit(rawValue: raw) ?? .km
    }
}
