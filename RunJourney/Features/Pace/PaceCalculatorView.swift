import SwiftUI
import SwiftData

/// ペース計算機。Web 版 marathon-record-app の `PaceCalculatorPage` を iOS ネイティブに移植したもの。
///
/// 主要機能:
/// - 距離プリセット (5K / 10K / Half / Full / Ultra100K / Custom) — `PaceRaceType`
/// - 距離変更時に `PACE_DEFAULT_GOAL_TIMES` のデフォルト目標タイムを自動ロード
/// - Sub-X 階層クイック設定 (`GoalTimeQuickSelect`)
/// - 目標タイム ↔ ペースの双方向同期 (`PaceTimeSpinner` × 2)
/// - スプリット表 (HALF/GOAL マーク付き)
/// - SwiftData の `PacePlan` 保存・読込・削除
/// - 画像出力 (`PaceShareCard` + `ImageRenderer` で 1080x1920 PNG → ShareLink)
struct PaceCalculatorView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PacePlan.createdAt, order: .reverse) private var savedPlans: [PacePlan]

    @State private var raceType: PaceRaceType = .full
    /// Custom distance はアプリ全体で共有 (Settings タブでも編集可)。
    @AppStorage("customDistanceKm") private var customDistanceKm: Double = 10
    /// 表示単位 (km / mi) — Settings で切替。Pace Calculator は全数値表示に反映。
    @AppStorage("distanceUnit") private var distanceUnitRaw: String = DistanceUnit.km.rawValue
    /// 目標タイム (秒)
    @State private var goalTimeSeconds: Int = PaceConstants.defaultGoalTimes[.full]!
    /// ペース (秒/km)
    @State private var pacePerKm: Int = PaceUtils.goalTimeToPace(
        goalTimeSeconds: PaceConstants.defaultGoalTimes[.full]!,
        distanceKm: 42.195
    )
    @State private var planName: String = ""

    @State private var showShareSheet = false

    /// Custom 距離 TextField のテキスト (表示単位ベース)。`customDistanceKm` (km 内部値) と同期。
    @State private var customDistanceText: String = ""

    private var unit: DistanceUnit { DistanceUnit.resolve(distanceUnitRaw) }

    /// PaceTimeSpinner 用: 表示単位の sec ↔ 内部 sec/km をブリッジ。
    /// km → そのまま。mi → displayed sec/mi を sec/km に逆変換 (× 1/1.609344)。
    private var pacePerUnitBinding: Binding<Int> {
        Binding(
            get: { PaceUtils.paceSecondsPerUnit(secPerKm: pacePerKm, in: unit) },
            set: { displayed in
                pacePerKm = unit == .km
                    ? displayed
                    : Int((Double(displayed) / kmPerMile).rounded())
            }
        )
    }

    /// 内部同期のサプレスフラグ。goalTime → pace と pace → goalTime の双方向に
    /// .onChange を貼ると無限ループするので、片方を変える時だけサプレスする。
    @State private var suppressSync = false

    /// ラップ毎のペース上書き (index → 秒/km)。スピナーで個別に編集した結果を保持する。
    /// 距離やレース種別が変わると無効になるのでクリアする。
    @State private var lapPaceOverrides: [Int: Int] = [:]

    /// 現在編集中のラップ。nil でないとき LapPaceEditor シートを表示する。
    @State private var editingLap: PaceLapSegment?

    // MARK: - Derived

    private var distanceKm: Double {
        if raceType == .custom { return max(0.1, customDistanceKm) }
        return PaceConstants.configs[raceType]?.distanceKm ?? 0
    }

    /// custom 用の lapInterval は距離に応じて適応。
    private var effectiveConfig: PaceRaceConfig {
        if let cfg = PaceConstants.configs[raceType] { return cfg }
        // custom: 距離が長いほどラップ間隔も大きく
        let lap: Double
        switch distanceKm {
        case ..<8:    lap = 1
        case ..<25:   lap = 2
        case ..<60:   lap = 5
        default:      lap = 10
        }
        return PaceRaceConfig(key: .custom, distanceKm: distanceKm, lapIntervalKm: lap)
    }

    private var laps: [PaceLapSegment] {
        guard distanceKm > 0, pacePerKm > 0 else { return [] }
        return PaceUtils.generateLaps(
            config: effectiveConfig,
            goalTimeSeconds: goalTimeSeconds,
            paceOverride: pacePerKm,
            perLapOverrides: lapPaceOverrides
        )
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Pace Calculator")
                    .appText(.displayLg)
                    .foregroundStyle(Color.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                distanceSection
                if raceType == .custom {
                    customDistanceField
                }
                if !SubTargetGroups.all[raceType, default: []].isEmpty {
                    GoalTimeQuickSelect(
                        raceType: raceType,
                        goalTimeSeconds: goalTimeSeconds,
                        onSelect: { sec in
                            applyGoalTime(sec)
                        }
                    )
                }
                spinnersGrid
                resultHero
                if !laps.isEmpty {
                    splitsSection
                }
                shareSection
                saveSection
                if !savedPlans.isEmpty {
                    savedPlansSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Color.bgPrimary)
#if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
#endif
        .onChange(of: raceType) { _, newType in
            lapPaceOverrides.removeAll()
            applyDefaultsForRaceType(newType)
        }
        .onChange(of: customDistanceKm) { _, _ in
            if raceType == .custom {
                lapPaceOverrides.removeAll()
                // custom 距離が変わったら現在のペースから目標タイムを再計算
                applyPace(pacePerKm)
            }
        }
        .onChange(of: goalTimeSeconds) { _, newSec in
            guard !suppressSync, distanceKm > 0 else { return }
            lapPaceOverrides.removeAll()
            suppressSync = true
            pacePerKm = PaceUtils.goalTimeToPace(goalTimeSeconds: newSec, distanceKm: distanceKm)
            DispatchQueue.main.async { suppressSync = false }
        }
        .onChange(of: pacePerKm) { _, newPace in
            guard !suppressSync, distanceKm > 0 else { return }
            lapPaceOverrides.removeAll()
            suppressSync = true
            goalTimeSeconds = PaceUtils.paceToGoalTime(pacePerKm: newPace, distanceKm: distanceKm)
            DispatchQueue.main.async { suppressSync = false }
        }
        .sheet(isPresented: $showShareSheet) {
            PaceShareSheet(
                raceType: raceType,
                distanceKm: distanceKm,
                goalTimeSeconds: goalTimeSeconds,
                pacePerKm: pacePerKm,
                laps: laps
            )
        }
        .sheet(item: $editingLap) { lap in
            LapPaceEditor(
                lap: lap,
                initialPace: lapPaceOverrides[lap.index] ?? lap.pacePerKm,
                onCancel: { editingLap = nil },
                onCommit: { newPace in
                    lapPaceOverrides[lap.index] = newPace
                    editingLap = nil
                },
                onReset: {
                    lapPaceOverrides.removeValue(forKey: lap.index)
                    editingLap = nil
                }
            )
        }
    }

    // MARK: - Distance section

    private var distanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Distance")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PaceConstants.order) { type in
                        DistanceTab(
                            label: type.label,
                            isActive: raceType == type,
                            action: { raceType = type }
                        )
                    }
                }
            }
        }
    }

    private var customDistanceField: some View {
        HStack {
            Text("Custom Distance")
                .appText(.bodySm)
                .foregroundStyle(.secondary)
            Spacer()
#if os(iOS)
            TextField(unit.label, text: $customDistanceText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.appFont(.codeBaseBold))
                .frame(width: 80)
                .onAppear { customDistanceText = formatCustomDistanceText() }
                .onSubmit { commitCustomDistanceText() }
#else
            TextField(unit.label, text: $customDistanceText)
                .multilineTextAlignment(.trailing)
                .font(.appFont(.codeBaseBold))
                .frame(width: 80)
                .onAppear { customDistanceText = formatCustomDistanceText() }
                .onSubmit { commitCustomDistanceText() }
#endif
            Text(unit.label)
                .appText(.bodySm)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 10))
        .onChange(of: distanceUnitRaw) { _, _ in customDistanceText = formatCustomDistanceText() }
        .onChange(of: customDistanceKm) { _, _ in customDistanceText = formatCustomDistanceText() }
    }

    private func formatCustomDistanceText() -> String {
        let v = customDistanceKm.displayed(in: unit)
        return abs(v) >= 10 ? String(format: "%.1f", v) : String(format: "%.2f", v)
    }

    private func commitCustomDistanceText() {
        let normalized = customDistanceText
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        guard let parsed = Double(normalized), parsed > 0 else {
            customDistanceText = formatCustomDistanceText()
            return
        }
        customDistanceKm = parsed.toKm(from: unit)
        customDistanceText = formatCustomDistanceText()
    }

    // MARK: - Spinners

    private var spinnersGrid: some View {
        HStack(alignment: .top, spacing: 10) {
            PaceTimeSpinner(
                title: "Goal Time",
                mode: .goalTime,
                seconds: $goalTimeSeconds,
                derivedGoalTimeSeconds: nil
            )
            PaceTimeSpinner(
                title: "Pace \(unit.perLabel)",
                mode: .pace,
                seconds: pacePerUnitBinding,
                derivedGoalTimeSeconds: PaceUtils.paceToGoalTime(pacePerKm: pacePerKm, distanceKm: distanceKm)
            )
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Result hero

    private var resultHero: some View {
        VStack(alignment: .leading, spacing: 8) {
            // カード内ラベルなので 24pt 中タイトルではなく eyebrow (10pt キャプション) を使う
            Text("Average Pace \(unit.perLabel)")
                .appText(.eyebrow)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline) {
                Text(PaceUtils.formatPaceSimple(PaceUtils.paceSecondsPerUnit(secPerKm: pacePerKm, in: unit)))
                    .appText(.codeXl)
                    .foregroundStyle(Color.accentPrimary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(PaceUtils.formatDistance(km: distanceKm, in: unit))
                        .appText(.codeSm)
                        .foregroundStyle(.secondary)
                    Text(PaceUtils.formatTimeSimple(goalTimeSeconds))
                        .appText(.codeMd)
                        .foregroundStyle(Color.textPrimary)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Splits

    private var splitsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Splits")
            PaceTable(
                laps: laps,
                raceLabel: raceType == .custom
                    ? PaceUtils.formatDistance(km: distanceKm, in: unit)
                    : raceType.labelLong,
                basePace: pacePerKm,
                onTapLap: { lap in editingLap = lap }
            )
        }
    }

    // MARK: - Share

    private var shareSection: some View {
        Button {
            showShareSheet = true
        } label: {
            HStack {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                Text("Share Image")
                    .appText(.bodyBaseBold)
            }
            .foregroundStyle(Color.bgPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.accentPrimary, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Save section

    private var saveSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Save Plan")
            HStack(spacing: 8) {
                TextField("Plan name (e.g. Sub 4)", text: $planName)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 10))
                Button {
                    savePlan()
                } label: {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.bgPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.accentPrimary, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(planName.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(planName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
            }
        }
    }

    private var savedPlansSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Saved Plans")
            VStack(spacing: 6) {
                ForEach(savedPlans) { plan in
                    Button {
                        loadPlan(plan)
                    } label: {
                        SavedPlanRow(plan: plan)
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button(role: .destructive) {
                            modelContext.delete(plan)
                            try? modelContext.save()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            Text("Tap a row to load, swipe to delete")
                .appText(.bodyXs)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Actions

    private func applyDefaultsForRaceType(_ type: PaceRaceType) {
        suppressSync = true
        if let def = PaceConstants.defaultGoalTimes[type] {
            goalTimeSeconds = def
            pacePerKm = PaceUtils.goalTimeToPace(goalTimeSeconds: def, distanceKm: distanceKm)
        } else {
            // custom: 直近の pace を維持し、distance に合わせて目標タイムを再計算
            goalTimeSeconds = PaceUtils.paceToGoalTime(pacePerKm: pacePerKm, distanceKm: distanceKm)
        }
        DispatchQueue.main.async { suppressSync = false }
    }

    private func applyGoalTime(_ sec: Int) {
        suppressSync = true
        goalTimeSeconds = sec
        pacePerKm = PaceUtils.goalTimeToPace(goalTimeSeconds: sec, distanceKm: distanceKm)
        DispatchQueue.main.async { suppressSync = false }
    }

    private func applyPace(_ pace: Int) {
        suppressSync = true
        pacePerKm = pace
        goalTimeSeconds = PaceUtils.paceToGoalTime(pacePerKm: pace, distanceKm: distanceKm)
        DispatchQueue.main.async { suppressSync = false }
    }

    private func savePlan() {
        let trimmed = planName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let plan = PacePlan(
            name: trimmed,
            targetDistanceKm: distanceKm,
            targetTimeSec: Double(goalTimeSeconds),
            raceTypeRaw: raceType.rawValue
        )
        modelContext.insert(plan)
        try? modelContext.save()
        planName = ""
    }

    private func loadPlan(_ plan: PacePlan) {
        // raceTypeRaw を優先、無ければ距離マッチング (後方互換)
        lapPaceOverrides.removeAll()
        suppressSync = true
        if let raw = plan.raceTypeRaw, let type = PaceRaceType(rawValue: raw) {
            raceType = type
            if type == .custom { customDistanceKm = plan.targetDistanceKm }
        } else if let match = PaceConstants.configs.first(where: { abs($0.value.distanceKm - plan.targetDistanceKm) < 0.01 }) {
            raceType = match.key
        } else {
            raceType = .custom
            customDistanceKm = plan.targetDistanceKm
        }
        goalTimeSeconds = Int(plan.targetTimeSec)
        pacePerKm = PaceUtils.goalTimeToPace(goalTimeSeconds: goalTimeSeconds, distanceKm: distanceKm)
        planName = plan.name
        DispatchQueue.main.async { suppressSync = false }
    }
}

// MARK: - Subcomponents

private struct DistanceTab: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .appText(.displayXs)
                .foregroundStyle(isActive ? Color.bgPrimary : Color.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    isActive ? Color.accentPrimary : Color.bgSecondary,
                    in: RoundedRectangle(cornerRadius: 10)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(isActive ? .clear : .white.opacity(0.1), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct SavedPlanRow: View {
    let plan: PacePlan
    @AppStorage("distanceUnit") private var distanceUnitRaw: String = DistanceUnit.km.rawValue
    private var unit: DistanceUnit { DistanceUnit.resolve(distanceUnitRaw) }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(plan.name)
                    .appText(.bodySmBold)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Text("\(PaceUtils.formatDistance(km: plan.targetDistanceKm, in: unit)) · \(PaceUtils.formatTimeSimple(Int(plan.targetTimeSec)))")
                    .appText(.codeXs)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(PaceUtils.formatPace(secPerKm: Int(plan.paceSecPerKm), in: unit))
                .appText(.codeMd)
                .foregroundStyle(Color.accentPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 10))
    }
}
