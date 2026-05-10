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

    @AppStorage("distanceUnit") private var distanceUnitRaw: String = DistanceUnit.km.rawValue
    private var unit: DistanceUnit { DistanceUnit.resolve(distanceUnitRaw) }

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
            .navigationTitle("CONFIRM IMPORT")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") { confirm() }
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
        Section {
            if let date = activity.startDate {
                LabeledContent("Date", value: date.formatted(date: .abbreviated, time: .shortened))
            }
            LabeledContent("Distance", value: PaceUtils.formatDistance(km: activity.totalDistanceKm, in: unit))
            if let sec = activity.finishTimeSec {
                LabeledContent("Time", value: PaceUtils.formatDuration(sec))
            }
            LabeledContent("Category (auto)", value: activity.estimatedCategory.displayName)
            if let coord = activity.startCoordinate {
                LabeledContent("Start", value: String(format: "%.4f, %.4f", coord.latitude, coord.longitude))
            }
            LabeledContent("Track Points", value: "\(activity.trackPoints.count)")
            LabeledContent("Laps", value: "\(activity.laps.count)")
        } header: {
            SectionHeader(title: "Activity Summary")
        }
    }

    @ViewBuilder
    private var modePickerSection: some View {
        Section {
            Picker("Save To", selection: $mode) {
                Text("New Race").tag(Mode.newRace)
                Text("Attach to Existing Race")
                    .tag(Mode.existingRace)
            }
            .pickerStyle(.segmented)
            .disabled(existingRaces.isEmpty)
        } footer: {
            if existingRaces.isEmpty {
                Text("No races registered yet — only \"New Race\" is available.")
            } else if mode == .existingRace, !nearbyRaces.isEmpty {
                Text("\(nearbyRaces.count) race(s) within \(PaceUtils.formatDistance(km: 5, in: unit)) of the start (great for year-over-year comparison).")
            }
        }
    }

    @ViewBuilder
    private var newRaceSection: some View {
        Section {
            raceNameField
            LabeledContent("Category", value: activity.estimatedCategory.displayName)
            Text("Category and start location are auto-inferred from the activity. Edit later from the detail view.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            SectionHeader(title: "New Race")
        }
    }

    /// プラットフォーム差異を吸収（textInputAutocapitalization は iOS only）。
    @ViewBuilder
    private var raceNameField: some View {
#if os(iOS)
        TextField("Race Name", text: $newRaceName)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
#else
        TextField("Race Name", text: $newRaceName)
            .autocorrectionDisabled()
#endif
    }

    @ViewBuilder
    private var existingRaceSection: some View {
        Section {
            if !nearbyRaces.isEmpty {
                Text("Nearby Races")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                ForEach(nearbyRaces) { race in
                    raceRow(race, isNearby: true)
                }
            }
            if !existingRaces.filter({ !nearbyRaces.contains($0) }).isEmpty {
                Text("Other Races")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                ForEach(existingRaces.filter { !nearbyRaces.contains($0) }) { race in
                    raceRow(race, isNearby: false)
                }
            }
        } header: {
            SectionHeader(title: "Pick a race to attach")
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
                            Text("· \(count) result(s)")
                        }
                        if isNearby {
                            Text("· nearby")
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

}
