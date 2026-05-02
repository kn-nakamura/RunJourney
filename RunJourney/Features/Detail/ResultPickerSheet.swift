import SwiftUI
import SwiftData

/// レース内の結果を複数選択して一括削除するためのピッカーシート。
/// `RaceDeleteSheet` の "Delete Results..." から開く。
/// 各行はチェックサークルで選択状態を切り替え、右上の "Delete (n)" → alert → 確定で削除。
/// 削除完了時のみ `onComplete` を呼び、親シート (RaceDeleteSheet) ごと閉じて RaceDetailView に戻す。
struct ResultPickerSheet: View {
    let race: Race
    let onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selected: Set<PersistentIdentifier> = []
    @State private var showAlert = false

    private var sortedResults: [RaceResult] {
        (race.results ?? []).sorted { $0.raceDate > $1.raceDate }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Tap to select results to delete. This cannot be undone.")
                        .appText(.bodyXs)
                        .foregroundStyle(.tertiary)

                    if sortedResults.isEmpty {
                        Text("No results to delete.")
                            .appText(.bodySm)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 40)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(sortedResults.enumerated()), id: \.element.persistentModelID) { idx, result in
                                Button {
                                    toggle(result)
                                } label: {
                                    row(result: result, isSelected: selected.contains(result.persistentModelID))
                                }
                                .buttonStyle(.plain)
                                if idx < sortedResults.count - 1 {
                                    rowDivider
                                }
                            }
                        }
                        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
            .background(Color.bgPrimary)
            .navigationTitle("Select Results")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAlert = true
                    } label: {
                        Text("Delete (\(selected.count))")
                            .appText(.bodyBaseBold)
                            .foregroundStyle(selected.isEmpty ? .secondary : Color.accentPrimary)
                    }
                    .disabled(selected.isEmpty)
                }
            }
            .alert(
                "Delete \(selected.count) result\(selected.count == 1 ? "" : "s")?",
                isPresented: $showAlert
            ) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    performDelete()
                    dismiss()
                    onComplete()
                }
            } message: {
                Text("This cannot be undone.")
            }
        }
    }

    private func toggle(_ result: RaceResult) {
        let id = result.persistentModelID
        if selected.contains(id) {
            selected.remove(id)
        } else {
            selected.insert(id)
        }
    }

    private func performDelete() {
        for r in sortedResults where selected.contains(r.persistentModelID) {
            AttachmentStore.deleteAll(ownerID: r.id)
            modelContext.delete(r)
        }
        try? modelContext.save()
    }

    private func row(result: RaceResult, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isSelected ? Color.accentPrimary : .secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(result.raceDate.formatted(date: .abbreviated, time: .omitted))
                    .appText(.bodyBaseBold)
                    .foregroundStyle(Color.textPrimary)
                HStack(spacing: 8) {
                    if let sec = result.finishTimeSec, sec > 0 {
                        Text(formatDuration(sec))
                            .appText(.codeSm)
                            .foregroundStyle(.secondary)
                    } else if result.isDNF {
                        Text("DNF").appText(.bodyXs).foregroundStyle(.red)
                    } else if result.isDNS {
                        Text("DNS").appText(.bodyXs).foregroundStyle(.secondary)
                    }
                    if let dist = result.summary?.totalDistanceM {
                        Text(String(format: "%.2f km", dist / 1000))
                            .appText(.codeXs)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.06))
            .frame(height: 0.5)
            .padding(.leading, 50)
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
