import SwiftUI

/// Attachments セクション右肩の `+` メニュー。
/// 各アクションはセクション側の state を立てるだけ（fileImporter / PhotosPicker は親に置く）。
///
/// `binaryRequiresPremium == true` のときは PDF / Image にロックアイコンを併記する。
/// タップ自体は受け付け、親 (= AttachmentSection) が paywall を出すか実 import を行うかを判断する。
struct AddAttachmentMenu: View {
    var binaryRequiresPremium: Bool = false
    let onAddText: () -> Void
    let onAddLink: () -> Void
    let onAddPDF:  () -> Void
    let onAddImage: () -> Void

    var body: some View {
        Menu {
            Button { onAddText() } label: {
                Label("Add Note", systemImage: AttachmentKind.text.systemImageName)
            }
            Button { onAddLink() } label: {
                Label("Add Link", systemImage: AttachmentKind.url.systemImageName)
            }
            Button { onAddPDF() } label: {
                Label(binaryRequiresPremium ? "Add PDF (Premium)" : "Add PDF",
                      systemImage: AttachmentKind.pdf.systemImageName)
            }
            Button { onAddImage() } label: {
                Label(binaryRequiresPremium ? "Add Image (Premium)" : "Add Image",
                      systemImage: AttachmentKind.image.systemImageName)
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.accentPrimary)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add Attachment")
    }
}
