import SwiftUI
import SwiftData

/// 2〜4 件の RaceResult を選択するシート。最初に選んだレースのカテゴリで全体を絞り込み、
/// 異種カテゴリ混在を防ぐ。空選択もサポート (= キャンセルでなく単に何もしない)。
struct ComparisonPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \RaceResult.raceDate, order: .reverse) private var allResults: [RaceResult]

    /// 親が seed として渡す既選択 ID 群。
    let initialSelection: [UUID]
    /// 親が「これと同じカテゴリだけ選ばせたい」場合に渡す lock。nil なら最初の選択でロックする。
    let lockedCategory: RaceCategory?
    let onCommit: ([UUID]) -> Void

    @State private var selection: Set<UUID>

    init(
        initialSelection: [UUID] = [],
        lockedCategory: RaceCategory? = nil,
        onCommit: @escaping ([UUID]) -> Void
    ) {
        self.initialSelection = initialSelection
        self.lockedCategory = lockedCategory
        self.onCommit = onCommit
        _selection = State(initialValue: Set(initialSelection))
    }

    /// 動的に決まる「絞り込み対象カテゴリ」。lockedCategory > 既選択の最初のカテゴリ。
    private var effectiveCategory: RaceCategory? {
        if let cat = lockedCategory { return cat }
        return selection
            .compactMap { id in allResults.first(where: { $0.id == id })?.race?.category }
            .first
    }

    private var visibleResults: [RaceResult] {
        guard let cat = effectiveCategory else { return allResults }
        return allResults.filter { $0.race?.category == cat }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if visibleResults.isEmpty {
                        Text("No results to compare")
                            .appText(.bodySm)
                            .foregroundStyle(.tertiary)
                    } else {
                        ForEach(visibleResults) { r in
                            Button {
                                toggle(r.id)
                            } label: {
                                row(r)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    SectionHeader(
                        title: "Pick 2 – 4",
                        subtitle: effectiveCategory?.displayName
                    )
                } footer: {
                    Text("Categories cannot be mixed. Tap to add or remove.")
                }
            }
            .navigationTitle("Compare Results")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onCommit(Array(selection))
                        dismiss()
                    }
                    .disabled(selection.count < 2)
                }
            }
        }
    }

    private func row(_ r: RaceResult) -> some View {
        HStack(spacing: 12) {
            Image(systemName: selection.contains(r.id) ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(selection.contains(r.id) ? Color.accentPrimary : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(r.race?.name ?? "—")
                    .appText(.bodySmBold)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Text(r.raceDate.formatted(date: .abbreviated, time: .omitted))
                    .appText(.bodyXs)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            if let sec = r.finishTimeSec, sec > 0 {
                Text(PaceUtils.formatDuration(sec))
                    .appText(.codeBaseBold)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func toggle(_ id: UUID) {
        if selection.contains(id) {
            selection.remove(id)
        } else if selection.count < 4 {
            selection.insert(id)
        }
    }

}
