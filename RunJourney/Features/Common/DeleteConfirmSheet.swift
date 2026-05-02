import SwiftUI

/// 削除アクションの2段階確認シート。
/// 入口（呼び出し側）はツールバー右上の小さな🗑 (`.secondary` 色) を想定し、
/// このシートは "説明 + Confirm Deletion" の中間ウインドウとして機能する。
/// `Confirm Deletion` をタップすると最終的な `.alert(...)` (Cancel / Delete) が表示され、
/// Delete を押した時のみ `onDelete()` が呼ばれる。誤操作で削除に至らないことを優先した構造。
struct DeleteConfirmSheet: View {
    let title: String
    let message: String
    let confirmLabel: String
    let finalAlertTitle: String
    let finalAlertMessage: String
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showFinalAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionHeader(title: title)

            Text(message)
                .appText(.bodySm)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            VStack(spacing: 10) {
                Button {
                    showFinalAlert = true
                } label: {
                    Text(confirmLabel)
                        .appText(.bodyBaseBold)
                        .foregroundStyle(Color.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .appText(.bodyBase)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bgPrimary)
        .alert(finalAlertTitle, isPresented: $showFinalAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
                dismiss()
            }
        } message: {
            Text(finalAlertMessage)
        }
    }
}

#Preview {
    DeleteConfirmSheet(
        title: "Delete Race",
        message: "This will permanently delete the race and 3 linked results.",
        confirmLabel: "Confirm Deletion",
        finalAlertTitle: "Delete this race?",
        finalAlertMessage: "This cannot be undone.",
        onDelete: {}
    )
    .preferredColorScheme(.dark)
}
