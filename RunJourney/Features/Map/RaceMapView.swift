import SwiftUI
import SwiftData
import MapKit

/// メインの地図画面。全レースを色分けピンで表示し、タップで詳細を開く。
struct RaceMapView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Race.createdAt, order: .reverse) private var races: [Race]

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedRace: Race?
    @State private var mapStyle: MapStyleChoice = .standard
    @State private var showAddSheet = false
    @State private var addCandidate: AddRaceCandidate?

    var body: some View {
        Map(position: $cameraPosition, selection: $selectedRace) {
            ForEach(races) { race in
                Annotation(race.name.isEmpty ? "レース" : race.name, coordinate: race.coordinate) {
                    RaceAnnotationView(race: race, isSelected: selectedRace == race)
                }
                .tag(race)
            }
        }
        .mapStyle(mapStyle.style)
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .overlay(alignment: .top) {
            if races.isEmpty {
                Text("右上の + ボタンを押して最初のレースを追加してみてください")
                    .font(.callout)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                    .padding()
                    .transition(.opacity)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: addDummyRaceNearTokyo) {
                    Label("レース追加", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Picker("地図スタイル", selection: $mapStyle) {
                    ForEach(MapStyleChoice.allCases) { choice in
                        Label(choice.displayName, systemImage: choice.symbolName)
                            .tag(choice)
                    }
                }
                .pickerStyle(.menu)
            }
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    fitAllRaces()
                } label: {
                    Label("全レースを表示", systemImage: "scope")
                }
                .disabled(races.isEmpty)
            }
        }
        .navigationTitle("RunJourney")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .sheet(item: $selectedRace) { race in
            NavigationStack {
                RaceDetailPlaceholder(race: race)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("閉じる") { selectedRace = nil }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
    }

    /// MVP用ダミー追加。Phase 3 で TCX/GPX/FIT 取り込みダイアログに置き換える。
    private func addDummyRaceNearTokyo() {
        let samples: [(String, RaceCategory, Double, Double, String)] = [
            ("東京マラソン", .fullMarathon, 35.6909, 139.6917, "Tokyo"),
            ("湘南国際マラソン", .fullMarathon, 35.3220, 139.4811, "Fujisawa"),
            ("大阪マラソン", .fullMarathon, 34.6937, 135.5023, "Osaka"),
            ("北海道マラソン", .fullMarathon, 43.0667, 141.3500, "Sapporo"),
            ("ハセツネカップ", .trail, 35.7375, 139.1453, "Tokyo"),
            ("青梅マラソン", .halfMarathon, 35.7878, 139.2756, "Ome"),
            ("板橋Cityマラソン", .fullMarathon, 35.7611, 139.6833, "Itabashi"),
            ("UTMF", .ultraCustom, 35.4361, 138.7186, "Fujikawaguchiko"),
        ]
        let pick = samples[races.count % samples.count]
        let race = Race(
            name: pick.0,
            category: pick.1,
            address: pick.4,
            city: pick.4,
            country: "Japan",
            lat: pick.2,
            lng: pick.3
        )
        modelContext.insert(race)
    }

    private func fitAllRaces() {
        guard !races.isEmpty else { return }
        let lats = races.map(\.lat)
        let lngs = races.map(\.lng)
        let minLat = lats.min()!
        let maxLat = lats.max()!
        let minLng = lngs.min()!
        let maxLng = lngs.max()!
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )
        // 周辺余白を1.5倍持たせる
        let span = MKCoordinateSpan(
            latitudeDelta: max(maxLat - minLat, 0.05) * 1.5,
            longitudeDelta: max(maxLng - minLng, 0.05) * 1.5
        )
        withAnimation(.easeInOut(duration: 0.6)) {
            cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
        }
    }
}

// MARK: - Map style choice

enum MapStyleChoice: String, CaseIterable, Identifiable {
    case standard
    case hybrid
    case imagery

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard: return "標準"
        case .hybrid: return "ハイブリッド"
        case .imagery: return "航空写真"
        }
    }

    var symbolName: String {
        switch self {
        case .standard: return "map"
        case .hybrid: return "map.fill"
        case .imagery: return "globe"
        }
    }

    var style: MapStyle {
        switch self {
        case .standard: return .standard(elevation: .realistic)
        case .hybrid: return .hybrid(elevation: .realistic)
        case .imagery: return .imagery(elevation: .realistic)
        }
    }
}

// MARK: - Long-press add candidate (Phase 2c用、現状未使用)

struct AddRaceCandidate: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

// MARK: - Detail placeholder (一時)

/// Phase 4 で正式な RaceDetailView に置き換える。
struct RaceDetailPlaceholder: View {
    @Bindable var race: Race
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("基本情報") {
                TextField("レース名", text: $race.name)
                Picker("カテゴリ", selection: $race.category) {
                    ForEach(RaceCategory.allCases) { cat in
                        Label(cat.displayName, systemImage: cat.symbolName)
                            .tag(cat)
                    }
                }
                if let km = race.distanceKm {
                    LabeledContent("距離", value: String(format: "%.2f km", km))
                }
                LabeledContent("地点", value: String(format: "%.4f, %.4f", race.lat, race.lng))
                if let city = race.city {
                    LabeledContent("都市", value: city)
                }
            }
            Section("結果") {
                if let count = race.results?.count, count > 0 {
                    Text("\(count) 件の結果")
                } else {
                    Text("まだ結果が登録されていません")
                        .foregroundStyle(.secondary)
                }
                Text("Phase 4 で結果一覧UI、Phase 3 で TCX/GPX/FIT 取り込みを実装")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Section {
                Button(role: .destructive) {
                    modelContext.delete(race)
                    dismiss()
                } label: {
                    Label("レースを削除", systemImage: "trash")
                }
            }
        }
        .navigationTitle(race.name.isEmpty ? "(無題)" : race.name)
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }
}
