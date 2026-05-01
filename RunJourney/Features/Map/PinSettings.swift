import SwiftUI

/// マップピンのカスタマイズ設定。`@AppStorage("pinSettings")` で永続化する。
struct PinSettings: Codable, Equatable {

    enum Shape: String, CaseIterable, Codable, Identifiable {
        case dot, ring, pin, square
        var id: String { rawValue }
        var label: String {
            switch self {
            case .dot:    return "ドット"
            case .ring:   return "リング"
            case .pin:    return "ピン"
            case .square: return "四角"
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
            case .never:        return "なし"
            case .selectedOnly: return "選択時"
            case .always:       return "常時"
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
            case .category: return "カテゴリ"
            case .accent:   return "アクセント"
            case .mono:     return "モノクロ"
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
            case .small:  return "小"
            case .medium: return "中"
            case .large:  return "大"
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
    @AppStorage("pinSettings_v1") private var raw: String = ""

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
