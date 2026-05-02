import SwiftUI
import MapKit

/// マップ全体の見た目を司る設定。`@AppStorage("mapStyleSettings")` で永続化する。
/// Web 版 marathon-record-app の `MapStyleSwitcher` を MapKit が出せる範囲で再現する。
struct MapStyleSettings: Codable, Equatable {

    enum Base: String, CaseIterable, Codable, Identifiable {
        case standard, hybrid, imagery
        var id: String { rawValue }
        var label: String {
            switch self {
            case .standard: return "Standard"
            case .hybrid:   return "Hybrid"
            case .imagery:  return "Imagery"
            }
        }
        var symbol: String {
            switch self {
            case .standard: return "map"
            case .hybrid:   return "map.fill"
            case .imagery:  return "globe"
            }
        }
    }

    enum Elevation: String, CaseIterable, Codable, Identifiable {
        case flat, realistic
        var id: String { rawValue }
        var label: String { self == .flat ? "Flat" : "3D" }
        var symbol: String { self == .flat ? "square" : "mountain.2.fill" }
    }

    enum ColorMode: String, CaseIterable, Codable, Identifiable {
        case auto, dark, light
        var id: String { rawValue }
        var label: String {
            switch self {
            case .auto:  return "Auto"
            case .dark:  return "Dark"
            case .light: return "Light"
            }
        }
        var symbol: String {
            switch self {
            case .auto:  return "circle.lefthalf.filled"
            case .dark:  return "moon.fill"
            case .light: return "sun.max.fill"
            }
        }
    }

    enum POIMode: String, CaseIterable, Codable, Identifiable {
        case none, minimal, all
        var id: String { rawValue }
        var label: String {
            switch self {
            case .none:    return "Off"
            case .minimal: return "Min"
            case .all:     return "All"
            }
        }
        var symbol: String {
            switch self {
            case .none:    return "eye.slash"
            case .minimal: return "text.magnifyingglass"
            case .all:     return "text.bubble"
            }
        }
    }

    var base: Base = .standard
    var elevation: Elevation = .realistic
    var colorMode: ColorMode = .dark
    var poi: POIMode = .none
    var showsTraffic: Bool = false

    static let `default` = MapStyleSettings()
}

extension MapStyleSettings {

    /// 適用する MapStyle。SwiftUI Map の `.mapStyle()` に渡す。
    /// 標準スタイルは `emphasis: .muted` で施設アイコン・道路ラベルを大幅に抑える。
    var mapStyle: MapStyle {
        let elev: MapStyle.Elevation = (elevation == .realistic ? .realistic : .flat)
        switch base {
        case .standard:
            return .standard(
                elevation: elev,
                emphasis: .muted,
                pointsOfInterest: poiCategories,
                showsTraffic: showsTraffic
            )
        case .hybrid:
            return .hybrid(
                elevation: elev,
                pointsOfInterest: poiCategories,
                showsTraffic: showsTraffic
            )
        case .imagery:
            return .imagery(elevation: elev)
        }
    }

    /// 表示する POI カテゴリ。MapKit の挙動上「ラベル全消し」は完全には保証されないが、
    /// `.excludingAll` でほぼ POI を抑止できる。
    var poiCategories: PointOfInterestCategories {
        switch poi {
        case .none:    return .excludingAll
        case .minimal: return .including([.airport, .hospital, .park, .stadium])
        case .all:     return .all
        }
    }

    /// Map に強制する ColorScheme（auto は nil でシステム任せ）。
    var preferredColorScheme: ColorScheme? {
        switch colorMode {
        case .auto:  return nil
        case .dark:  return .dark
        case .light: return .light
        }
    }

    /// 航空写真では POI / Traffic / Color が無視されるので UI 側で disable する。
    var allowsColorMode: Bool { base != .imagery }
    var allowsPOI: Bool { base != .imagery }
    var allowsTraffic: Bool { base == .standard }
}

// MARK: - @AppStorage 用ラッパー

/// `@AppStorage` は Codable struct を直接持てないので JSON 文字列に詰める。
@propertyWrapper
struct StoredMapStyleSettings: DynamicProperty {
    @AppStorage("mapStyleSettings_v1") private var raw: String = ""

    var wrappedValue: MapStyleSettings {
        get {
            guard !raw.isEmpty,
                  let data = raw.data(using: .utf8),
                  let value = try? JSONDecoder().decode(MapStyleSettings.self, from: data)
            else { return .default }
            return value
        }
        nonmutating set {
            guard let data = try? JSONEncoder().encode(newValue),
                  let s = String(data: data, encoding: .utf8)
            else { return }
            raw = s
        }
    }

    var projectedValue: Binding<MapStyleSettings> {
        Binding(get: { wrappedValue }, set: { wrappedValue = $0 })
    }
}
