import SwiftUI
import SwiftData

/// Settings 画面下部の "Delete data..." 行から開くシート。
/// 4つの削除スコープ（Results / Races / Plans / Everything）を控えめなグレー行で並べ、
/// 各行タップで `.alert(...)` を出して最終確認 → 確定で実削除する。
/// 旧 SettingsView の dataSection を切り出した構造で、配色を `.red` から `.secondary` に変更し、
/// 入口（Settings本体）からは目立たない位置に隔離するのが目的。
struct DataManagementSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var races: [Race]
    @Query private var results: [RaceResult]
    @Query private var plans: [PacePlan]

    @State private var pendingScope: SettingsView.DeleteScope?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Manage Data")

            Text("Choose what to delete. This cannot be undone.")
                .appText(.bodyXs)
                .foregroundStyle(.tertiary)

            VStack(spacing: 0) {
                ForEach(Array(SettingsView.DeleteScope.allCases.enumerated()), id: \.element) { idx, scope in
                    Button {
                        pendingScope = scope
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 24)
                            Text("Delete \(scope.displayName)")
                                .appText(.bodyBase)
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if idx < SettingsView.DeleteScope.allCases.count - 1 {
                        rowDivider
                    }
                }
            }
            .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))

            Text("If iCloud sync is enabled, deletions also propagate to all linked devices.")
                .appText(.bodyXs)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 4)

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bgPrimary)
        .alert(
            pendingScope.map { "Delete \($0.displayName)?" } ?? "",
            isPresented: Binding(
                get: { pendingScope != nil },
                set: { if !$0 { pendingScope = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) { pendingScope = nil }
            Button("Delete", role: .destructive) {
                if let scope = pendingScope {
                    performDelete(scope: scope)
                }
                pendingScope = nil
                dismiss()
            }
        } message: {
            Text(pendingScope?.summary ?? "")
        }
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.06))
            .frame(height: 0.5)
            .padding(.leading, 50)
    }

    private func performDelete(scope: SettingsView.DeleteScope) {
        switch scope {
        case .results:
            for r in results { modelContext.delete(r) }
        case .races:
            for r in races { modelContext.delete(r) }   // cascade で結果も消える
        case .plans:
            for p in plans { modelContext.delete(p) }
        case .everything:
            for r in results { modelContext.delete(r) }
            for r in races { modelContext.delete(r) }
            for p in plans { modelContext.delete(p) }
        }
        try? modelContext.save()
    }
}
