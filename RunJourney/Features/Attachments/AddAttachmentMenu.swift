import SwiftUI

/// Attachments セクション右肩の `+` メニュー。
/// 各アクションはセクション側の state を立てるだけ（fileImporter / PhotosPicker は親に置く）。
struct AddAttachmentMenu: View {
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
                Label("Add PDF", systemImage: AttachmentKind.pdf.systemImageName)
            }
            Button { onAddImage() } label: {
                Label("Add Image", systemImage: AttachmentKind.image.systemImageName)
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
