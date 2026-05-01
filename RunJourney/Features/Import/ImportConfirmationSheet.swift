import SwiftUI
import SwiftData
import CoreLocation

/// 取り込み確認シート。
/// ファイルパース後に表示され、ユーザーは「新規大会」 or 「既存大会の結果として追加」を選択する。
/// Webアプリの「マラソン大会(Race) → 各回の結果(RaceResult)」モデルに合わせた重要なフロー。
struct ImportConfirmationSheet: View {
    let activity: ParsedActivity
    let fileName: String?

    /// 確定時のクロージャ。呼び出し側が ActivityImporter を呼ぶ。
    let onConfirm: (ImportTarget) -> Void
    let onCancel: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Race.createdAt, order: .reverse) private var existingRaces: [Race]

    @State private var mode: Mode = .newRace
    @State private var newRaceName: String = ""
    @State private var selectedRace: Race?

    enum Mode: String, CaseIterable, Identifiable {
        case newRace
        case existingRace
        var id: String { rawValue }
    }

    enum ImportTarget {
        case newRace(name: String)
        case existing(race: Race)
    }

    /// 開始地点に近い既存レース（5km以内）。優先候補として上位に出す。
    private var nearbyRaces: [Race] {
        guard let start = activity.startCoordinate else { return [] }
        return existingRaces.filter { race in
            let dist = ActivityMath.haversineMeters(
                lat1: start.latitude, lon1: start.longitude,
                lat2: race.lat, lon2: race.lng
            )
            return dist < 5000
        }
    }

    private var canConfirm: Bool {
        switch mode {
        case .newRace: return !newRaceName.trimmingCharacters(in: .whitespaces).isEmpty
        case .existingRace: return selectedRace != nil
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                activitySummarySection
                modePickerSection
                if mode == .newRace {
                    newRaceSection
                } else {
                    existingRaceSection
                }
            }
            .navigationTitle("取り込み確認")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("取り込む") { confirm() }
                        .disabled(!canConfirm)
                }
            }
            .onAppear {
                // 初期値をセット
                newRaceName = ActivityImporter.defaultRaceName(activity: activity, fileName: fileName)
                if !nearbyRaces.isEmpty {
                    // 近場に既存大会があればそれをプレ選択（モードはnewRaceのまま、ユーザーが切り替えれば即選ばれる）
                    selectedRace = nearbyRaces.first
                } else if !existingRaces.isEmpty {
                    selectedRace = existingRaces.first
                }
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var activitySummarySection: some View {
        Section("アクティビティ概要") {
            if let date = activity.startDate {
                LabeledContent("日付", value: date.formatted(date: .abbreviated, time: .shortened))
            }
            LabeledContent("距離", value: String(format: "%.2f km", activity.totalDistanceKm))
            if let sec = activity.finishTimeSec {
                LabeledContent("タイム", value: formatDuration(sec))
            }
            LabeledContent("推定カテゴリ", value: activity.estimatedCategory.displayName)
            if let coord = activity.startCoordinate {
                LabeledContent("開始地点", value: String(format: "%.4f, %.4f", coord.latitude, coord.longitude))
            }
            LabeledContent("トラックポイント", value: "\(activity.trackPoints.count)")
            LabeledContent("ラップ", value: "\(activity.laps.count)")
        }
    }

    @ViewBuilder
    private var modePickerSection: some View {
        Section {
            Picker("保存先", selection: $mode) {
                Text("新しい大会として作成").tag(Mode.newRace)
                Text("既存の大会に結果を追加")
                    .tag(Mode.existingRace)
            }
            .pickerStyle(.segmented)
            .disabled(existingRaces.isEmpty)
        } footer: {
            if existingRaces.isEmpty {
                Text("まだ大会が登録されていないので「新しい大会として作成」のみ選択できます。")
            } else if mode == .existingRace, !nearbyRaces.isEmpty {
                Text("開始地点から5km以内の大会が \(nearbyRaces.count) 件あります（年別比較に便利）")
            }
        }
    }

    @ViewBuilder
    private var newRaceSection: some View {
        Section("新しい大会") {
            TextField("大会名", text: $newRaceName)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            LabeledContent("カテゴリ", value: activity.estimatedCategory.displayName)
            Text("カテゴリと開始地点はアクティビティから自動推定されます。あとで詳細画面で編集できます。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var existingRaceSection: some View {
        Section {
            if !nearbyRaces.isEmpty {
                Text("開始地点周辺")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                ForEach(nearbyRaces) { race in
                    raceRow(race, isNearby: true)
                }
            }
            if !existingRaces.filter({ !nearbyRaces.contains($0) }).isEmpty {
                Text("その他の大会")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                ForEach(existingRaces.filter { !nearbyRaces.contains($0) }) { race in
                    raceRow(race, isNearby: false)
                }
            }
        } header: {
            Text("追加先の大会を選択")
        }
    }

    @ViewBuilder
    private func raceRow(_ race: Race, isNearby: Bool) -> some View {
        Button {
            selectedRace = race
        } label: {
            HStack(spacing: 10) {
                Image(systemName: race.category.symbolName)
                    .foregroundStyle(race.category.pinColor)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(race.name)
                        .foregroundStyle(.primary)
                    HStack(spacing: 6) {
                        Text(race.category.displayName)
                        if let count = race.results?.count, count > 0 {
                            Text("・ 結果 \(count)件")
                        }
                        if isNearby {
                            Text("・ 近場")
                                .foregroundStyle(.tint)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                if selectedRace == race {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func confirm() {
        switch mode {
        case .newRace:
            onConfirm(.newRace(name: newRaceName.trimmingCharacters(in: .whitespaces)))
        case .existingRace:
            if let race = selectedRace {
                onConfirm(.existing(race: race))
            }
        }
    }

    private func formatDuration(_ totalSec: Double) -> String {
        let s = Int(totalSec)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }
}
