import SwiftUI
import SwiftData

/// ペース計算機。目標タイムから1kmあたりのペースとスプリット時間表を生成。
/// プランをSwiftDataに保存して再利用できる。
struct PaceCalculatorView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PacePlan.createdAt, order: .reverse) private var savedPlans: [PacePlan]

    @State private var distanceChoice: DistanceChoice = .fullMarathon
    @State private var customDistanceKm: Double = 42.195
    @State private var hours: Int = 4
    @State private var minutes: Int = 0
    @State private var seconds: Int = 0
    @State private var planName: String = ""

    enum DistanceChoice: String, CaseIterable, Identifiable {
        case fiveK, tenK, halfMarathon, fullMarathon, custom
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .fiveK: return "5km"
            case .tenK: return "10km"
            case .halfMarathon: return "ハーフ"
            case .fullMarathon: return "フル"
            case .custom: return "カスタム"
            }
        }
        var distanceKm: Double {
            switch self {
            case .fiveK: return 5
            case .tenK: return 10
            case .halfMarathon: return 21.0975
            case .fullMarathon: return 42.195
            case .custom: return 0  // ユーザー入力
            }
        }
    }

    private var distanceKm: Double {
        distanceChoice == .custom ? customDistanceKm : distanceChoice.distanceKm
    }

    private var totalSeconds: Double {
        Double(hours * 3600 + minutes * 60 + seconds)
    }

    private var paceSecPerKm: Double? {
        guard distanceKm > 0, totalSeconds > 0 else { return nil }
        return totalSeconds / distanceKm
    }

    private var splits: [(km: Double, cumulativeSec: Double)] {
        guard let pace = paceSecPerKm, distanceKm > 0 else { return [] }
        var rows: [(Double, Double)] = []
        // 1km刻み
        let step = 1.0
        var k = step
        while k < distanceKm {
            rows.append((k, k * pace))
            k += step
        }
        // 最終（端数）距離
        rows.append((distanceKm, distanceKm * pace))
        return rows
    }

    var body: some View {
        Form {
            distanceSection
            goalTimeSection
            resultSection
            if !splits.isEmpty {
                splitsSection
            }
            saveSection
            if !savedPlans.isEmpty {
                savedPlansSection
            }
        }
        .navigationTitle("ペース計算")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }

    // MARK: - Sections

    private var distanceSection: some View {
        Section("距離") {
            Picker("距離", selection: $distanceChoice) {
                ForEach(DistanceChoice.allCases) { choice in
                    Text(choice.displayName).tag(choice)
                }
            }
            .pickerStyle(.segmented)
            if distanceChoice == .custom {
                HStack {
                    Text("距離")
                    Spacer()
                    customDistanceField
                    Text("km").foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var customDistanceField: some View {
#if os(iOS)
        TextField("km", value: $customDistanceKm, format: .number)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .frame(width: 100)
#else
        TextField("km", value: $customDistanceKm, format: .number)
            .multilineTextAlignment(.trailing)
            .frame(width: 100)
#endif
    }

    private var goalTimeSection: some View {
        Section("目標タイム") {
#if os(iOS)
            HStack(spacing: 12) {
                wheel(label: "時", value: $hours, range: 0...23)
                wheel(label: "分", value: $minutes, range: 0...59)
                wheel(label: "秒", value: $seconds, range: 0...59)
            }
            .frame(height: 130)
#else
            HStack(spacing: 16) {
                stepperBlock(label: "時", value: $hours, range: 0...23)
                stepperBlock(label: "分", value: $minutes, range: 0...59)
                stepperBlock(label: "秒", value: $seconds, range: 0...59)
            }
#endif
        }
    }

#if os(iOS)
    @ViewBuilder
    private func wheel(label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        VStack(spacing: 2) {
            Picker(label, selection: value) {
                ForEach(range, id: \.self) { i in
                    Text(String(format: "%02d", i)).tag(i)
                        .font(.mono(18, bold: true))
                }
            }
            .labelsHidden()
            .pickerStyle(.wheel)
            Text(label).font(.body(11)).foregroundStyle(.secondary)
        }
    }
#else
    @ViewBuilder
    private func stepperBlock(label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        VStack(spacing: 4) {
            Text(String(format: "%02d", value.wrappedValue))
                .font(.mono(24, bold: true))
                .foregroundStyle(Color.accentPrimary)
            Stepper("", value: value, in: range)
                .labelsHidden()
            Text(label)
                .font(.body(11))
                .foregroundStyle(.secondary)
        }
    }
#endif

    private var resultSection: some View {
        Section("結果") {
            if let pace = paceSecPerKm {
                LabeledContent {
                    Text(formatPace(pace))
                        .font(.display(28))
                        .foregroundStyle(Color.accentPrimary)
                } label: {
                    Text("平均ペース /km")
                        .font(.body(13))
                }
                LabeledContent("距離", value: String(format: "%.3f km", distanceKm))
                LabeledContent("総時間", value: formatDuration(totalSeconds))
            } else {
                Text("距離と目標タイムを入力してください")
                    .font(.body(13))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var splitsSection: some View {
        Section {
            ForEach(splits, id: \.km) { row in
                HStack {
                    Text(String(format: row.km == row.km.rounded() ? "%.0f km" : "%.2f km", row.km))
                        .font(.mono(13))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatDuration(row.cumulativeSec))
                        .font(.mono(15, bold: true))
                        .foregroundStyle(Color.textPrimary)
                }
            }
        } header: {
            Text("スプリット (累積時間)")
        }
    }

    private var saveSection: some View {
        Section("プラン保存") {
            TextField("プラン名 (例: サブ4)", text: $planName)
            Button {
                savePlan()
            } label: {
                Label("プランを保存", systemImage: "bookmark.fill")
            }
            .disabled(paceSecPerKm == nil || planName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private var savedPlansSection: some View {
        Section {
            ForEach(savedPlans) { plan in
                Button {
                    loadPlan(plan)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(plan.name)
                                .font(.body(14, weight: .bold))
                                .foregroundStyle(Color.textPrimary)
                            Text("\(String(format: "%.2f km", plan.targetDistanceKm)) ・ \(formatDuration(plan.targetTimeSec))")
                                .font(.mono(11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(formatPace(plan.paceSecPerKm))
                            .font(.display(20))
                            .foregroundStyle(Color.accentPrimary)
                    }
                }
                .buttonStyle(.plain)
            }
            .onDelete(perform: deletePlans)
        } header: {
            Text("保存済みプラン")
        } footer: {
            Text("行をタップで読み込み、スワイプで削除")
        }
    }

    // MARK: - Actions

    private func savePlan() {
        let trimmed = planName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let plan = PacePlan(
            name: trimmed,
            targetDistanceKm: distanceKm,
            targetTimeSec: totalSeconds
        )
        modelContext.insert(plan)
        try? modelContext.save()
        planName = ""
    }

    private func loadPlan(_ plan: PacePlan) {
        // 既存の DistanceChoice にマッチするか判定
        if let match = DistanceChoice.allCases.first(where: { abs($0.distanceKm - plan.targetDistanceKm) < 0.01 && $0 != .custom }) {
            distanceChoice = match
        } else {
            distanceChoice = .custom
            customDistanceKm = plan.targetDistanceKm
        }
        let total = Int(plan.targetTimeSec)
        hours = total / 3600
        minutes = (total % 3600) / 60
        seconds = total % 60
        planName = plan.name
    }

    private func deletePlans(at offsets: IndexSet) {
        for offset in offsets {
            modelContext.delete(savedPlans[offset])
        }
        try? modelContext.save()
    }

    // MARK: - Formatters

    private func formatPace(_ secPerKm: Double) -> String {
        let m = Int(secPerKm) / 60
        let s = Int(secPerKm) % 60
        return String(format: "%d:%02d", m, s)
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
