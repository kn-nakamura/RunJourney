import SwiftUI

/// マップピンのカスタマイズ設定。`@AppStorage("pinSettings")` で永続化する。
struct PinSettings: Codable, Equatable {

    enum Shape: String, CaseIterable, Codable, Identifiable {
        case dot, ring, pin, square
        var id: String { rawValue }
        var label: String {
            switch self {
            case .dot:    return "Dot"
            case .ring:   return "Ring"
            case .pin:    return "Pin"
            case .square: return "Square"
            }
        }
        var symbol: String {
            switch self {
            case .dot:    return "circle.fill"
            case .ring:   return "circle"
            case .pin:    return "mappin"
            case .square: return "square.fill"
            }
        }
    }

    enum SymbolMode: String, CaseIterable, Codable, Identifiable {
        case never, selectedOnly, always
        var id: String { rawValue }
        var label: String {
            switch self {
            case .never:        return "Off"
            case .selectedOnly: return "Selected"
            case .always:       return "Always"
            }
        }
        var symbol: String {
            switch self {
            case .never:        return "circle.slash"
            case .selectedOnly: return "hand.tap"
            case .always:       return "figure.run"
            }
        }
    }

    enum ColorSource: String, CaseIterable, Codable, Identifiable {
        case category, accent, mono
        var id: String { rawValue }
        var label: String {
            switch self {
            case .category: return "Category"
            case .accent:   return "Accent"
            case .mono:     return "Mono"
            }
        }
        var symbol: String {
            switch self {
            case .category: return "paintpalette"
            case .accent:   return "circle.fill"
            case .mono:     return "circle.lefthalf.filled"
            }
        }
    }

    enum Size: String, CaseIterable, Codable, Identifiable {
        case small, medium, large
        var id: String { rawValue }
        var label: String {
            switch self {
            case .small:  return "S"
            case .medium: return "M"
            case .large:  return "L"
            }
        }
        /// 通常時の直径 (pt)
        var dimension: CGFloat {
            switch self {
            case .small:  return 18
            case .medium: return 24
            case .large:  return 32
            }
        }
        /// 選択時の直径 (pt)
        var selectedDimension: CGFloat { dimension * 1.7 }
        /// 通常時のシンボル fontSize
        var symbolFontSize: CGFloat { dimension * 0.55 }
    }

    var shape: Shape = .dot
    var symbolMode: SymbolMode = .selectedOnly
    var colorSource: ColorSource = .category
    var size: Size = .medium
    var showBorder: Bool = true
    var showName: Bool = true

    static let `default` = PinSettings()
}

extension PinSettings {
    func resolvedColor(category: RaceCategory) -> Color {
        switch colorSource {
        case .category: return category.pinColor
        case .accent:   return .accentPrimary
        case .mono:     return .white
        }
    }
}

@propertyWrapper
struct StoredPinSettings: DynamicProperty {
    // v2 で互換破棄: MKMapView ベース移行に伴い既定値を確実に dot に戻すため
    // ストレージキーをバンプして旧 (v1) の永続化値を捨てる。
    @AppStorage("pinSettings_v2") private var raw: String = ""

    var wrappedValue: PinSettings {
        get {
            guard !raw.isEmpty,
                  let data = raw.data(using: .utf8),
                  let value = try? JSONDecoder().decode(PinSettings.self, from: data)
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

    var projectedValue: Binding<PinSettings> {
        Binding(get: { wrappedValue }, set: { wrappedValue = $0 })
    }
}
