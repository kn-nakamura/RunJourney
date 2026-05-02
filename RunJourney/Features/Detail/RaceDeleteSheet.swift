import SwiftUI
import SwiftData

/// RaceDetailView 下部の小さな🗑から開く削除ハブ。
/// - "Delete Results..." → さらに選択ピッカー (`ResultPickerSheet`) を開いて任意の結果のみ削除
/// - "Delete Entire Race" → 確認 alert → race + 全結果を削除
/// 配色は Settings の DataManagementSheet と揃え、目立たせず必要時だけ使える形にする。
struct RaceDeleteSheet: View {
    let race: Race
    /// "Delete Entire Race" 経路で race を削除した後に呼ぶ。親 (RaceDetailView) を pop するために使う。
    let onRaceDeleted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var showRaceDeleteAlert = false
    @State private var showResultPicker = false

    private var resultCount: Int { race.results?.count ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Delete")

            Text("Choose what to delete. This cannot be undone.")
                .appText(.bodyXs)
                .foregroundStyle(.tertiary)

            VStack(spacing: 0) {
                Button {
                    showResultPicker = true
                } label: {
                    optionRow(
                        label: "Delete Results...",
                        sublabel: resultCount == 0 ? "No results yet" : "\(resultCount) result\(resultCount == 1 ? "" : "s")"
                    )
                }
                .buttonStyle(.plain)
                .disabled(resultCount == 0)
                .opacity(resultCount == 0 ? 0.5 : 1)

                rowDivider

                Button {
                    showRaceDeleteAlert = true
                } label: {
                    optionRow(
                        label: "Delete Entire Race",
                        sublabel: resultCount == 0
                            ? "Race entry only"
                            : "Race + \(resultCount) linked result\(resultCount == 1 ? "" : "s")"
                    )
                }
                .buttonStyle(.plain)
            }
            .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bgPrimary)
        .alert("Delete this race?", isPresented: $showRaceDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                modelContext.delete(race)
                try? modelContext.save()
                dismiss()
                onRaceDeleted()
            }
        } message: {
            Text(resultCount == 0
                 ? "This will permanently delete this race entry."
                 : "This will permanently delete the race and \(resultCount) linked result\(resultCount == 1 ? "" : "s").")
        }
        .sheet(isPresented: $showResultPicker) {
            ResultPickerSheet(race: race) {
                // 結果削除が完了したらピッカーは自分で閉じ、ここで親シートも閉じて RaceDetailView に戻す。
                dismiss()
            }
        }
    }

    private func optionRow(label: String, sublabel: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "trash")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .appText(.bodyBase)
                    .foregroundStyle(Color.textPrimary)
                Text(sublabel)
                    .appText(.bodyXs)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
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
}
