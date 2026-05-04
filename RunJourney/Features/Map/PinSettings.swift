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

    /// ピンサイズの自動調整モード。
    /// - off: 固定サイズ (現状互換)
    /// - zoom: ズームレベルに応じてサイズ可変。広域で小さく、街区レベルで通常サイズに戻る。
    /// - density: 画面上で密集しているピンを小さく、孤立ピンを通常サイズで描画 (Google Maps 風)。
    /// - cluster: MKMapView 標準クラスタリングで密集ピンを件数バッジに集約。
    enum AdaptiveSizing: String, CaseIterable, Codable, Identifiable {
        case off, zoom, density, cluster
        var id: String { rawValue }
        var label: String {
            switch self {
            case .off:     return "Off"
            case .zoom:    return "Zoom"
            case .density: return "Density"
            case .cluster: return "Cluster"
            }
        }
        var symbol: String {
            switch self {
            case .off:     return "circle.slash"
            case .zoom:    return "arrow.up.left.and.down.right.magnifyingglass"
            case .density: return "circle.grid.3x3.fill"
            case .cluster: return "square.stack.3d.up.fill"
            }
        }
    }

    var shape: Shape = .dot
    var symbolMode: SymbolMode = .selectedOnly
    var colorSource: ColorSource = .category
    var size: Size = .medium
    var adaptiveSizing: AdaptiveSizing = .off
    var showBorder: Bool = true
    var showName: Bool = true

    static let `default` = PinSettings()
}

// 旧バージョン (`adaptiveSizing` キーが存在しない v2 の永続化データ) を読んだときも
// 他のフィールドを保持できるよう、欠落キーは個別フィールドのデフォルトにフォール
// バックする。custom init は extension に置いて synthesized memberwise init
// (`PinSettings(shape:)` などプレビューで使用) を温存する。
extension PinSettings {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.shape          = try c.decodeIfPresent(Shape.self,          forKey: .shape)          ?? .dot
        self.symbolMode     = try c.decodeIfPresent(SymbolMode.self,     forKey: .symbolMode)     ?? .selectedOnly
        self.colorSource    = try c.decodeIfPresent(ColorSource.self,    forKey: .colorSource)    ?? .category
        self.size           = try c.decodeIfPresent(Size.self,           forKey: .size)           ?? .medium
        self.adaptiveSizing = try c.decodeIfPresent(AdaptiveSizing.self, forKey: .adaptiveSizing) ?? .off
        self.showBorder     = try c.decodeIfPresent(Bool.self,           forKey: .showBorder)     ?? true
        self.showName       = try c.decodeIfPresent(Bool.self,           forKey: .showName)       ?? true
    }

    private enum CodingKeys: String, CodingKey {
        case shape, symbolMode, colorSource, size, adaptiveSizing, showBorder, showName
    }
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
