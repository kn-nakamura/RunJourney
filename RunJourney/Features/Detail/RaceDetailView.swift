import SwiftUI
import SwiftData

/// 大会(Race)の詳細ビュー。
/// - 基本情報（名前・カテゴリ・距離・地点）
/// - 結果一覧（複数の参加結果、各行は RaceResultDetailView へナビゲート）
/// - 比較セクション（2件以上ある場合: 年別タイム棒グラフ + ラップペース重ね合わせ）
/// - 大会自体の削除
struct RaceDetailView: View {
    @Bindable var race: Race
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showComparison = false

    private var sortedResults: [RaceResult] {
        (race.results ?? []).sorted { $0.raceDate > $1.raceDate }
    }

    private var pbSeconds: Double? {
        sortedResults
            .compactMap { ($0.isDNF || $0.isDNS) ? nil : $0.finishTimeSec }
            .min()
    }

    var body: some View {
        Form {
            basicInfoSection
            resultsSection
            if sortedResults.count >= 2 {
                comparisonSection
            }
            deleteSection
        }
        .navigationTitle(race.name.isEmpty ? "(無題)" : race.name)
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }

    // MARK: - Basic info

    private var basicInfoSection: some View {
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
    }

    // MARK: - Results

    private var resultsSection: some View {
        Section {
            if sortedResults.isEmpty {
                Text("まだ結果が登録されていません")
                    .foregroundStyle(.secondary)
                Text("地図のツールバー ↓ から TCX/GPX/FIT/ZIP を取り込むと、確認シートで「既存の大会に結果を追加」を選んでこの大会の結果として登録できます。")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(sortedResults) { result in
                    NavigationLink {
                        RaceResultDetailView(result: result)
                    } label: {
                        RaceResultRow(result: result, isPB: result.finishTimeSec == pbSeconds && pbSeconds != nil)
                    }
                }
                .onDelete { offsets in
                    for offset in offsets {
                        modelContext.delete(sortedResults[offset])
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
                Text("行をタップで詳細・チャート表示。下の「比較」セクションで重ね合わせ表示できます。")
            }
        }
    }

    // MARK: - Comparison

    private var comparisonSection: some View {
        Section {
            DisclosureGroup(isExpanded: $showComparison) {
                VStack(alignment: .leading, spacing: 12) {
                    if sortedResults.contains(where: { ($0.finishTimeSec ?? 0) > 0 }) {
                        Text("フィニッシュタイム")
                            .font(.body(13, weight: .bold))
                            .foregroundStyle(.secondary)
                        FinishTimeComparisonChart(results: sortedResults)
                    }
                    if sortedResults.contains(where: { !$0.lapData.isEmpty }) {
                        Text("ラップ別ペース重ね合わせ")
                            .font(.body(13, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                        MultiResultLapPaceChart(results: sortedResults)
                    }
                }
                .padding(.vertical, 4)
            } label: {
                Label("年別比較", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.body(15, weight: .bold))
            }
        }
    }

    // MARK: - Delete

    private var deleteSection: some View {
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
}

/// 結果一覧の1行（RaceDetailViewから NavigationLink のラベルとして使う）。
struct RaceResultRow: View {
    let result: RaceResult
    let isPB: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(result.raceDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.body(15, weight: .bold))
                if isPB {
                    Text("PB")
                        .font(.monoCaption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.pbBadge, in: Capsule())
                        .foregroundStyle(.black)
                }
                Spacer()
                if let sec = result.finishTimeSec {
                    Text(formatDuration(sec))
                        .font(.display(28))
                        .foregroundStyle(Color.accentPrimary)
                } else if result.isDNF {
                    Text("DNF").foregroundStyle(.red)
                } else if result.isDNS {
                    Text("DNS").foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 12) {
                if let dist = result.summary?.totalDistanceM {
                    Label(String(format: "%.2f km", dist / 1000), systemImage: "ruler")
                        .font(.mono(12))
                }
                if let pace = result.summary?.avgPaceSecPerKm {
                    Label(formatPace(pace), systemImage: "speedometer")
                        .font(.mono(12))
                }
                if let hr = result.summary?.avgHeartRate {
                    Label("\(hr) bpm", systemImage: "heart.fill")
                        .font(.mono(12))
                        .foregroundStyle(.red.opacity(0.85))
                }
            }
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
                .font(.mono(11))
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
