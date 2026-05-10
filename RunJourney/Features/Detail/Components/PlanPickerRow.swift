import SwiftUI
import SwiftData

/// `RaceResult` に紐付ける `PacePlan` を選択する行。距離が近い順に並べた Picker 1 つだけのシンプルな UI。
/// SwiftData の `linkedPacePlanId` (UUID) を読み書きする。
struct PlanPickerRow: View {
    @Bindable var result: RaceResult
    @Query(sort: \PacePlan.createdAt, order: .reverse) private var plans: [PacePlan]

    /// 距離一致度 (m 単位) で並べた選択肢。
    private var sortedPlans: [PacePlan] {
        let resultDistanceM = result.summary?.totalDistanceM ?? 0
        return plans.sorted { lhs, rhs in
            let lDiff = abs(lhs.targetDistanceKm * 1000 - resultDistanceM)
            let rDiff = abs(rhs.targetDistanceKm * 1000 - resultDistanceM)
            if lDiff != rDiff { return lDiff < rDiff }
            return lhs.createdAt > rhs.createdAt
        }
    }

    /// Picker の 2-way binding。SwiftData の UUID? を直接 Picker に渡せないので Optional 文字列にブリッジする。
    private var selectionBinding: Binding<String> {
        Binding(
            get: { result.linkedPacePlanId?.uuidString ?? "" },
            set: { newValue in
                result.linkedPacePlanId = newValue.isEmpty ? nil : UUID(uuidString: newValue)
            }
        )
    }

    var body: some View {
        Section {
            if plans.isEmpty {
                Text("No saved pace plans. Create one in the Pace tab to compare against this result.")
                    .appText(.bodyXs)
                    .foregroundStyle(.tertiary)
            } else {
                Picker("Plan", selection: selectionBinding) {
                    Text("None").tag("")
                    ForEach(sortedPlans, id: \.id) { plan in
                        Text(label(for: plan)).tag(plan.id.uuidString)
                    }
                }
            }
            if let plan = linkedPlan {
                HStack {
                    Text("Target pace")
                        .appText(.bodyXs)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Text("\(PaceUtils.formatPaceSimple(Int(plan.paceSecPerKm.rounded()))) /km")
                        .appText(.codeBaseBold)
                        .foregroundStyle(Color.accentPrimary)
                }
            }
        } header: {
            SectionHeader(title: "Pace Plan")
        } footer: {
            Text("Linking a plan enables \"Plan vs Actual\" splits, banked-time chart, and pace zone analysis on the result detail.")
        }
    }

    private var linkedPlan: PacePlan? {
        guard let id = result.linkedPacePlanId else { return nil }
        return plans.first { $0.id == id }
    }

    private func label(for plan: PacePlan) -> String {
        let distance = String(format: "%.2f km", plan.targetDistanceKm)
        let pace = "\(PaceUtils.formatPaceSimple(Int(plan.paceSecPerKm.rounded()))) /km"
        let name = plan.name.isEmpty ? "Plan" : plan.name
        return "\(name) · \(distance) @ \(pace)"
    }
}
