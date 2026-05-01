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

    /// 選択中レースの最初のトラックポイント付き結果のルートを描画する。
    private var selectedRouteCoordinates: [CLLocationCoordinate2D] {
        guard let race = selectedRace,
              let result = race.results?.first(where: { !$0.trackPoints.isEmpty })
        else { return [] }
        return result.trackPoints.map(\.coordinate)
    }

    var body: some View {
        Map(position: $cameraPosition, selection: $selectedRace) {
            ForEach(races) { race in
                Annotation(race.name.isEmpty ? "レース" : race.name, coordinate: race.coordinate) {
                    RaceAnnotationView(race: race, isSelected: selectedRace == race)
                }
                .tag(race)
            }

            if let race = selectedRace, !selectedRouteCoordinates.isEmpty {
                MapPolyline(coordinates: selectedRouteCoordinates)
                    .stroke(race.category.pinColor, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
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
                Text("ツールバーの ↓ から TCX / GPX を取り込み、または + でダミーレースを追加")
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
                FileImportButton()
            }
            ToolbarItem(placement: .secondaryAction) {
                Button(action: addDummyRaceNearTokyo) {
                    Label("ダミー追加", systemImage: "plus")
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
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    fitSelectedRoute()
                } label: {
                    Label("ルートにフィット", systemImage: "arrow.up.left.and.arrow.down.right")
                }
                .disabled(selectedRouteCoordinates.isEmpty)
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

    private func fitSelectedRoute() {
        let coords = selectedRouteCoordinates
        guard coords.count >= 2 else { return }
        let lats = coords.map(\.latitude)
        let lngs = coords.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lngs.min()! + lngs.max()!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(lats.max()! - lats.min()!, 0.005) * 1.4,
            longitudeDelta: max(lngs.max()! - lngs.min()!, 0.005) * 1.4
        )
        withAnimation(.easeInOut(duration: 0.6)) {
            cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
        }
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
/// 1つの大会(Race)に紐づく複数の結果(RaceResult)を一覧表示する。
struct RaceDetailPlaceholder: View {
    @Bindable var race: Race
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private var sortedResults: [RaceResult] {
        (race.results ?? []).sorted { $0.raceDate > $1.raceDate }
    }

    /// 同カテゴリでの自己ベスト（DNF/DNSは除外）— 表示時のPB判定に使う。
    private var pbSeconds: Double? {
        sortedResults
            .compactMap { ($0.isDNF || $0.isDNS) ? nil : $0.finishTimeSec }
            .min()
    }

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

            // 結果一覧（複数年の比較に使う重要セクション）
            Section {
                if sortedResults.isEmpty {
                    Text("まだ結果が登録されていません")
                        .foregroundStyle(.secondary)
                    Text("地図のツールバー ↓ から TCX/GPX/FIT/ZIP を取り込み、確認シートで「既存の大会に結果を追加」を選ぶと、この大会の結果として登録されます。")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(sortedResults) { result in
                        RaceResultRow(result: result, isPB: result.finishTimeSec == pbSeconds && pbSeconds != nil)
                    }
                    .onDelete { offsets in
                        for offset in offsets {
                            let result = sortedResults[offset]
                            modelContext.delete(result)
                        }
                        try? modelContext.save()
                    }
                }
            } header: {
                HStack {
                    Text("結果一覧")
                    Spacer()
                    Text("\(sortedResults.count)件")
                        .foregroundStyle(.secondary)
                }
            } footer: {
                if sortedResults.count >= 2 {
                    Text("複数年の結果を比較できます。Phase 4 で年別チャートを追加予定。")
                }
            }

            Section {
                Button(role: .destructive) {
                    modelContext.delete(race)
                    try? modelContext.save()
                    dismiss()
                } label: {
                    Label("大会を削除", systemImage: "trash")
                }
            } footer: {
                if !sortedResults.isEmpty {
                    Text("削除すると \(sortedResults.count) 件の結果も一緒に消えます。")
                }
            }
        }
        .navigationTitle(race.name.isEmpty ? "(無題)" : race.name)
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }
}

/// 結果一覧の1行。日付・タイム・距離・ペース・HRをコンパクトに表示。
private struct RaceResultRow: View {
    let result: RaceResult
    let isPB: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(result.raceDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline.bold())
                if isPB {
                    Text("PB")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.yellow.opacity(0.85), in: Capsule())
                        .foregroundStyle(.black)
                }
                Spacer()
                if let sec = result.finishTimeSec {
                    Text(formatDuration(sec))
                        .font(.headline.monospacedDigit())
                } else if result.isDNF {
                    Text("DNF").foregroundStyle(.red)
                } else if result.isDNS {
                    Text("DNS").foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 12) {
                if let dist = result.summary?.totalDistanceM {
                    Label(String(format: "%.2f km", dist / 1000), systemImage: "ruler")
                }
                if let pace = result.summary?.avgPaceSecPerKm {
                    Label(formatPace(pace), systemImage: "speedometer")
                }
                if let hr = result.summary?.avgHeartRate {
                    Label("\(hr) bpm", systemImage: "heart.fill")
                        .foregroundStyle(.red.opacity(0.8))
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if !result.lapData.isEmpty || !result.trackPoints.isEmpty {
                HStack(spacing: 12) {
                    if !result.lapData.isEmpty {
                        Text("ラップ \(result.lapData.count)")
                    }
                    if !result.trackPoints.isEmpty {
                        Text("ポイント \(result.trackPoints.count)")
                    }
                    if let elev = result.summary?.elevationGainM {
                        Text(String(format: "↑ %.0f m", elev))
                    }
                    if let cal = result.summary?.totalCalories {
                        Text(String(format: "%.0f kcal", cal))
                    }
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatDuration(_ totalSec: Double) -> String {
        let s = Int(totalSec)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }

    private func formatPace(_ secPerKm: Double) -> String {
        let m = Int(secPerKm) / 60
        let s = Int(secPerKm) % 60
        return String(format: "%d:%02d /km", m, s)
    }
}
