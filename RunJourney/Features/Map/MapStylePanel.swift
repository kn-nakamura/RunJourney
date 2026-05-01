import SwiftUI

/// 地図右下にフロートする「Layers」ボタンと、それを開いたときの設定パネル。
/// マップ全体（Style/Color/Elevation/POI/Traffic）とピン（Shape/Symbol/Color/Size/Border/Name）を
/// 一画面で切り替えられる。すべての変更は @AppStorage で即座に永続化される。
struct MapStylePanel: View {

    @Binding var mapSettings: MapStyleSettings
    @Binding var pinSettings: PinSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                mapSection
                pinSection
                resetSection
            }
            .navigationTitle("レイヤー")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
        }
    }

    // MARK: - Map

    private var mapSection: some View {
        Section {
            // Style — アイコンのみ。Standard / Hybrid / Imagery
            HStack {
                Label("スタイル", systemImage: "map")
                Spacer()
                Picker("スタイル", selection: $mapSettings.base) {
                    ForEach(MapStyleSettings.Base.allCases) { base in
                        Image(systemName: base.symbol).tag(base)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }

            // Color
            HStack {
                Label("カラー", systemImage: "paintbrush")
                Spacer()
                Picker("カラー", selection: $mapSettings.colorMode) {
                    ForEach(MapStyleSettings.ColorMode.allCases) { mode in
                        Image(systemName: mode.symbol).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
                .disabled(!mapSettings.allowsColorMode)
                .opacity(mapSettings.allowsColorMode ? 1 : 0.4)
            }

            // Elevation
            HStack {
                Label("起伏", systemImage: "mountain.2")
                Spacer()
                Picker("起伏", selection: $mapSettings.elevation) {
                    ForEach(MapStyleSettings.Elevation.allCases) { elev in
                        Text(elev.label).tag(elev)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }

            // POI（施設マーカー）
            HStack {
                Label("施設", systemImage: "tag")
                Spacer()
                Picker("施設", selection: $mapSettings.poi) {
                    ForEach(MapStyleSettings.POIMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
                .disabled(!mapSettings.allowsPOI)
                .opacity(mapSettings.allowsPOI ? 1 : 0.4)
            }

            // Traffic
            Toggle(isOn: $mapSettings.showsTraffic) {
                Label("交通情報", systemImage: "car.fill")
            }
            .disabled(!mapSettings.allowsTraffic)
            .opacity(mapSettings.allowsTraffic ? 1 : 0.4)
        } header: {
            Text("マップ")
        } footer: {
            Text("「施設」はカフェ・公園などのアイコンを抑制します。市町村名などの地理ラベルはApple Mapsの仕様で常に表示されます。")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Pin

    private var pinSection: some View {
        Section("ピン") {
            // Shape
            HStack {
                Label("形", systemImage: "circle.fill")
                Spacer()
                Picker("形", selection: $pinSettings.shape) {
                    ForEach(PinSettings.Shape.allCases) { s in
                        Image(systemName: s.symbol).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }

            // Symbol
            HStack {
                Label("シンボル", systemImage: "figure.run")
                Spacer()
                Picker("シンボル", selection: $pinSettings.symbolMode) {
                    ForEach(PinSettings.SymbolMode.allCases) { m in
                        Text(m.label).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }

            // Color
            HStack {
                Label("色", systemImage: "paintpalette")
                Spacer()
                Picker("色", selection: $pinSettings.colorSource) {
                    ForEach(PinSettings.ColorSource.allCases) { c in
                        Text(c.label).tag(c)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }

            // Size
            HStack {
                Label("サイズ", systemImage: "arrow.up.left.and.arrow.down.right")
                Spacer()
                Picker("サイズ", selection: $pinSettings.size) {
                    ForEach(PinSettings.Size.allCases) { s in
                        Text(s.label).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }

            Toggle(isOn: $pinSettings.showBorder) {
                Label("白枠", systemImage: "circle.dashed")
            }

            Toggle(isOn: $pinSettings.showName) {
                Label("名前ラベル", systemImage: "text.below.photo")
            }

            // プレビュー
            HStack {
                Spacer()
                VStack(spacing: 8) {
                    Text("プレビュー")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 24) {
                        ForEach([RaceCategory.fiveK, .halfMarathon, .fullMarathon, .trail], id: \.self) { cat in
                            VStack(spacing: 4) {
                                RaceAnnotationView(
                                    race: Race(name: cat.displayName, category: cat, lat: 0, lng: 0),
                                    isSelected: false,
                                    settings: pinSettings
                                )
                                Text(cat.displayName)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Spacer()
            }
            .padding(.vertical, 8)
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - Reset

    private var resetSection: some View {
        Section {
            Button(role: .destructive) {
                mapSettings = .default
                pinSettings = .default
            } label: {
                Label("デフォルトに戻す", systemImage: "arrow.uturn.backward")
            }
        }
    }
}

/// マップ右下にフロートする Layers ボタン。タップで `MapStylePanel` を開く。
struct LayersButton: View {
    @Binding var mapSettings: MapStyleSettings
    @Binding var pinSettings: PinSettings
    @State private var showingPanel = false

    var body: some View {
        Button {
            showingPanel = true
        } label: {
            Image(systemName: "square.3.layers.3d")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("レイヤー")
        .sheet(isPresented: $showingPanel) {
            MapStylePanel(mapSettings: $mapSettings, pinSettings: $pinSettings)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

#Preview {
    @Previewable @State var map = MapStyleSettings.default
    @Previewable @State var pin = PinSettings.default
    return MapStylePanel(mapSettings: $map, pinSettings: $pin)
}
