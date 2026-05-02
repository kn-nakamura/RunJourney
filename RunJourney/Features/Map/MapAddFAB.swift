import SwiftUI
import SwiftData
#if os(iOS)
import CoreLocation
#endif

/// マップ画面の最右下に置く蛍光イエローの大型 FAB。
///
/// タップでアクションシートを表示し:
/// - "Add Race" → 新規 Race を作成し、既存の `RaceDetailView` (= Race Info ダイアログ) を
///   開いて手動入力させる。Cancel で破棄、Close で保存維持。
/// - "Add Result" → レース選択 → 既存 `AddResultSheet` を開く (内部に FIT/GPX/TCX
///   インポート導線あり)。
///
/// 旧 `MapActionsCluster` 内の `FileImportButton` と "+ Add Sample" を統合してここに集約する。
/// ダミーサンプル投入は Settings → Developer に移設済み。
struct MapAddFAB: View {
    let races: [Race]

    @Environment(\.modelContext) private var modelContext

    @State private var showActionSheet: Bool = false
    @State private var newRace: Race? = nil
    @State private var showRacePicker: Bool = false
    @State private var pickedRace: Race? = nil
    /// 「Add Result → レース選択」のドロワー用。map のピン側とは連動させない
    /// (ローカルなピッカーなので、開く度にリセットされる挙動で良い)。
    @State private var pickerFilters = RaceFilters()

    var body: some View {
        Button {
            showActionSheet = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 26, weight: .heavy))
                .foregroundStyle(Color.bgPrimary)
                .frame(width: 60, height: 60)
                .background(
                    Circle()
                        .fill(Color.accentPrimary)
                )
                .overlay(
                    Circle()
                        .strokeBorder(.white.opacity(0.18), lineWidth: 0.8)
                )
                .shadow(color: Color.accentPrimary.opacity(0.45), radius: 14, y: 0)
                .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add")
        .confirmationDialog("Add", isPresented: $showActionSheet, titleVisibility: .visible) {
            Button("Add Race") {
                presentNewRace()
            }
            Button("Add Result") {
                if races.isEmpty {
                    presentNewRace()
                } else {
                    showRacePicker = true
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(races.isEmpty
                 ? "Create your first race, then attach results to it."
                 : "Choose what to add."
            )
        }
        // Add Race: 新規 Race を作って RaceDetailView (Race Info ダイアログ) を開く。
        // 専用フォームは廃止。RaceDetailView の Race Info セクションがそのまま編集 UI に
        // なるので、ここでは Cancel (= 破棄) / Close (= 保存維持) のツールバーだけ被せる。
        .sheet(item: $newRace) { race in
            NavigationStack {
                RaceDetailView(race: race)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                modelContext.delete(race)
                                try? modelContext.save()
                                newRace = nil
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                try? modelContext.save()
                                newRace = nil
                            }
                            .appText(.bodyBaseBold)
                        }
                    }
            }
        }
        .sheet(isPresented: $showRacePicker) {
            RaceListDrawer(
                races: races,
                filters: $pickerFilters,
                onSelect: { race in
                    showRacePicker = false
                    DispatchQueue.main.async {
                        pickedRace = race
                    }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: showRacePicker) { _, isShown in
            // ピッカーを閉じた次回開封時は条件をクリアして開きたい。
            if !isShown { pickerFilters = RaceFilters() }
        }
        .sheet(item: $pickedRace) { race in
            AddResultSheet(race: race)
        }
    }

    /// 新規 Race を modelContext に挿入して、`newRace` バインディングを叩いてシートを開く。
    /// `lat`/`lng` は 0/0 (未設定 sentinel) のままにし、ユーザが LocationSearchField で
    /// 位置を確定するまでマップにピンを立てない (RaceMapView 側で `lat==0 && lng==0` を除外)。
    /// これで「Add Race を押した瞬間に海上にピンが現れる」現象を回避。
    private func presentNewRace() {
        let race = Race(
            name: "",
            category: .fullMarathon,
            country: "Japan",
            lat: 0,
            lng: 0
        )
        modelContext.insert(race)
        newRace = race
    }
}
