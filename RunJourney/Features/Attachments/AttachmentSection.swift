import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

/// 1Password 風の添付フィールド群。Race / RaceResult どちらでも使えるジェネリック Section。
///
/// 表示位置は Form 内 1 セクション。`+` を押すと種別選択メニュー（Note / Link / PDF / Image）から
/// 1 件追加し、追加後に edit sheet を開く。各行はラベル inline 編集可。
struct AttachmentSection<Owner: AttachmentOwner>: View {

    let owner: Owner

    @Environment(\.modelContext) private var modelContext

    @State private var showFileImporter = false
    @State private var pendingPhotosItem: PhotosPickerItem? = nil
    @State private var editingAttachment: Attachment? = nil
    @State private var errorMessage: String? = nil
    @State private var showPhotosPicker = false

    private var sortedAttachments: [Attachment] {
        (owner.attachments ?? []).sorted {
            if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
            return $0.createdAt < $1.createdAt
        }
    }

    var body: some View {
        Section {
            if sortedAttachments.isEmpty {
                Text("No attachments yet")
                    .appText(.bodyXs)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(sortedAttachments) { attachment in
                    Button {
                        editingAttachment = attachment
                    } label: {
                        AttachmentRow(attachment: attachment)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: deleteAttachments)
            }

            if let errorMessage {
                Text(errorMessage)
                    .appText(.bodyXs)
                    .foregroundStyle(.red)
            }
        } header: {
            SectionHeader(title: "Attachments", subtitle: sortedAttachments.isEmpty ? nil : "\(sortedAttachments.count)") {
                AddAttachmentMenu(
                    onAddText: { addAttachment(kind: .text) },
                    onAddLink: { addAttachment(kind: .url) },
                    onAddPDF:  { showFileImporter = true },
                    onAddImage: { showPhotosPicker = true }
                )
            }
        } footer: {
            if sortedAttachments.isEmpty {
                Text("Add brochures, route maps, links and notes for this race.")
                    .appText(.bodyXs)
                    .foregroundStyle(.tertiary)
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false,
            onCompletion: handleFileImport
        )
        .photosPicker(
            isPresented: $showPhotosPicker,
            selection: $pendingPhotosItem,
            matching: .images,
            photoLibrary: .shared()
        )
        .onChange(of: pendingPhotosItem) { _, newItem in
            guard let item = newItem else { return }
            Task { await handlePickedImage(item) }
        }
        .sheet(item: $editingAttachment) { attachment in
            AttachmentEditSheet(attachment: attachment) {
                editingAttachment = nil
            }
        }
    }

    // MARK: - Add / Delete

    private func addAttachment(kind: AttachmentKind) {
        let label = defaultLabel(for: kind, urlString: nil, filename: nil)
        let attachment = Attachment(kind: kind, label: label)
        attachment.sortOrder = (sortedAttachments.last?.sortOrder ?? -1) + 1
        owner.bind(attachment)
        modelContext.insert(attachment)
        try? modelContext.save()
        editingAttachment = attachment
    }

    private func deleteAttachments(at offsets: IndexSet) {
        for index in offsets {
            let attachment = sortedAttachments[index]
            // ローカルファイル本体も掃除
            if attachment.relativePath != nil {
                AttachmentStore.delete(attachment.relativePath)
            }
            modelContext.delete(attachment)
        }
        try? modelContext.save()
    }

    // MARK: - Pickers

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let attachmentID = UUID()
                let ingested = try AttachmentStore.ingestPickedFile(
                    at: url,
                    ownerID: owner.id,
                    attachmentID: attachmentID
                )
                let filename = url.deletingPathExtension().lastPathComponent
                let attachment = Attachment(kind: .pdf, label: filename.isEmpty ? "PDF" : filename)
                attachment.id = attachmentID
                attachment.relativePath = ingested.relativePath
                attachment.originalFilename = url.lastPathComponent
                attachment.byteSize = ingested.byteSize
                attachment.mimeType = ingested.mimeType
                attachment.sortOrder = (sortedAttachments.last?.sortOrder ?? -1) + 1
                owner.bind(attachment)
                modelContext.insert(attachment)
                try? modelContext.save()
                errorMessage = nil
            } catch {
                errorMessage = "Failed to import PDF: \(error.localizedDescription)"
            }
        case .failure(let error):
            errorMessage = "Failed to pick file: \(error.localizedDescription)"
        }
    }

    private func handlePickedImage(_ item: PhotosPickerItem) async {
        defer { pendingPhotosItem = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                errorMessage = "Could not read picked image."
                return
            }
            let attachmentID = UUID()
            let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
            let relative = try AttachmentStore.save(data, ownerID: owner.id, attachmentID: attachmentID, ext: ext)
            let attachment = Attachment(kind: .image, label: "Image")
            attachment.id = attachmentID
            attachment.relativePath = relative
            attachment.byteSize = data.count
            attachment.mimeType = UTType(filenameExtension: ext)?.preferredMIMEType
            attachment.sortOrder = (sortedAttachments.last?.sortOrder ?? -1) + 1
            owner.bind(attachment)
            modelContext.insert(attachment)
            try? modelContext.save()
            errorMessage = nil
        } catch {
            errorMessage = "Failed to import image: \(error.localizedDescription)"
        }
    }

    // MARK: - Helpers

    private func defaultLabel(for kind: AttachmentKind, urlString: String?, filename: String?) -> String {
        switch kind {
        case .text:       return "Note"
        case .url:        return "Link"
        case .pdf:        return filename ?? "PDF"
        case .image:      return "Image"
        case .photoAsset: return "Photo"
        }
    }
}
