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
    @State private var customDistanceKm: Double = 10
    /// 目標タイム (秒)
    @State private var goalTimeSeconds: Int = PaceConstants.defaultGoalTimes[.full]!
    /// ペース (秒/km)
    @State private var pacePerKm: Int = PaceUtils.goalTimeToPace(
        goalTimeSeconds: PaceConstants.defaultGoalTimes[.full]!,
        distanceKm: 42.195
    )
    @State private var planName: String = ""

    @State private var showShareSheet = false

    /// 内部同期のサプレスフラグ。goalTime → pace と pace → goalTime の双方向に
    /// .onChange を貼ると無限ループするので、片方を変える時だけサプレスする。
    @State private var suppressSync = false

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
            paceOverride: pacePerKm
        )
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
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
        .navigationTitle("ペース計算")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .onChange(of: raceType) { _, newType in
            applyDefaultsForRaceType(newType)
        }
        .onChange(of: customDistanceKm) { _, _ in
            if raceType == .custom {
                // custom 距離が変わったら現在のペースから目標タイムを再計算
                applyPace(pacePerKm)
            }
        }
        .onChange(of: goalTimeSeconds) { _, newSec in
            guard !suppressSync, distanceKm > 0 else { return }
            suppressSync = true
            pacePerKm = PaceUtils.goalTimeToPace(goalTimeSeconds: newSec, distanceKm: distanceKm)
            DispatchQueue.main.async { suppressSync = false }
        }
        .onChange(of: pacePerKm) { _, newPace in
            guard !suppressSync, distanceKm > 0 else { return }
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
    }

    // MARK: - Distance section

    private var distanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("距離")
                .font(.body(10, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1)
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
            Text("カスタム距離")
                .font(.body(13))
                .foregroundStyle(.secondary)
            Spacer()
#if os(iOS)
            TextField("km", value: $customDistanceKm, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.mono(16, bold: true))
                .frame(width: 80)
#else
            TextField("km", value: $customDistanceKm, format: .number)
                .multilineTextAlignment(.trailing)
                .font(.mono(16, bold: true))
                .frame(width: 80)
#endif
            Text("km")
                .font(.body(13))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Spinners

    private var spinnersGrid: some View {
        HStack(spacing: 10) {
            PaceTimeSpinner(
                title: "Goal Time",
                mode: .goalTime,
                seconds: $goalTimeSeconds,
                derivedGoalTimeSeconds: nil
            )
            PaceTimeSpinner(
                title: "Pace / km",
                mode: .pace,
                seconds: $pacePerKm,
                derivedGoalTimeSeconds: PaceUtils.paceToGoalTime(pacePerKm: pacePerKm, distanceKm: distanceKm)
            )
        }
    }

    // MARK: - Result hero

    private var resultHero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("平均ペース /km")
                .font(.body(10, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1)
            HStack(alignment: .firstTextBaseline) {
                Text(PaceUtils.formatPaceSimple(pacePerKm))
                    .font(.display(56))
                    .foregroundStyle(Color.accentPrimary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(String(format: "%.3f", distanceKm)) km")
                        .font(.mono(13))
                        .foregroundStyle(.secondary)
                    Text(PaceUtils.formatTimeSimple(goalTimeSeconds))
                        .font(.display(28))
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
            Text("スプリット (累積時間)")
                .font(.body(10, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1)
            VStack(spacing: 4) {
                ForEach(laps) { lap in
                    HStack {
                        Text(lap.distanceLabel)
                            .font(.mono(13, bold: lap.distanceLabel == "GOAL" || lap.distanceLabel == "HALF"))
                            .foregroundStyle(lapLabelColor(for: lap))
                            .frame(width: 64, alignment: .leading)
                        Spacer()
                        Text(PaceUtils.formatTimeSimple(Int(lap.cumulativeTime)))
                            .font(.mono(15, bold: true))
                            .foregroundStyle(Color.textPrimary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private func lapLabelColor(for lap: PaceLapSegment) -> Color {
        switch lap.distanceLabel {
        case "GOAL": return Color.accentPrimary
        case "HALF": return .orange
        default: return .secondary
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
                Text("画像で共有")
                    .font(.body(15, weight: .bold))
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
            Text("プラン保存")
                .font(.body(10, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1)
            HStack(spacing: 8) {
                TextField("プラン名 (例: サブ4)", text: $planName)
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
            Text("保存済みプラン")
                .font(.body(10, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1)
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
                            Label("削除", systemImage: "trash")
                        }
                    }
                }
            }
            Text("行をタップで読み込み、長押し / スワイプで削除")
                .font(.body(11))
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
                .font(.display(18))
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

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(plan.name)
                    .font(.body(14, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Text("\(String(format: "%.2f km", plan.targetDistanceKm)) ・ \(PaceUtils.formatTimeSimple(Int(plan.targetTimeSec)))")
                    .font(.mono(11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(PaceUtils.formatPaceSimple(Int(plan.paceSecPerKm)))
                .font(.display(22))
                .foregroundStyle(Color.accentPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 10))
    }
}
