import SwiftUI
import SwiftData
import PhotosUI

/// Photos.app の画像をリンクとして紐付けるセクション。
///
/// `PhotosPicker(matching: .images, photoLibrary: .shared())` を使うと
/// `PhotosPickerItem.itemIdentifier` に PHAsset.localIdentifier が入る。
/// 画像本体はコピーせず、ID を `Attachment(kind: .photoAsset)` として保存する。
struct PhotoLinkSection<Owner: AttachmentOwner>: View {

    let owner: Owner

    @Environment(\.modelContext) private var modelContext

    @State private var pickerSelection: [PhotosPickerItem] = []
    @State private var errorMessage: String? = nil

    private var photoAttachments: [Attachment] {
        (owner.attachments ?? [])
            .filter { $0.kind == .photoAsset }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        Section {
            if photoAttachments.isEmpty {
                Text("Link photos from your library to remember this race.")
                    .appText(.bodyXs)
                    .foregroundStyle(.tertiary)
            } else {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(photoAttachments) { attachment in
                        ZStack(alignment: .topTrailing) {
                            if let id = attachment.phAssetLocalID {
                                PhotoAssetThumbnail(localIdentifier: id, size: 110)
                            } else {
                                Color.bgTertiary
                                    .frame(width: 110, height: 110)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            Button {
                                modelContext.delete(attachment)
                                try? modelContext.save()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(.white, .black.opacity(0.55))
                                    .padding(4)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove photo")
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            PhotosPicker(
                selection: $pickerSelection,
                maxSelectionCount: 0,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label(
                    photoAttachments.isEmpty ? "Add Photos" : "Add More Photos",
                    systemImage: "photo.on.rectangle.angled"
                )
                .appText(.bodySmBold)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.bgTertiary)
            .foregroundStyle(Color.textPrimary)

            if let errorMessage {
                Text(errorMessage)
                    .appText(.bodyXs)
                    .foregroundStyle(.red)
            }
        } header: {
            SectionHeader(title: "Photos", subtitle: photoAttachments.isEmpty ? nil : "\(photoAttachments.count)")
        }
        .onChange(of: pickerSelection) { _, newItems in
            guard !newItems.isEmpty else { return }
            handlePicked(newItems)
        }
    }

    private func handlePicked(_ items: [PhotosPickerItem]) {
        let existing = Set(photoAttachments.compactMap { $0.phAssetLocalID })
        var sortBase = ((owner.attachments ?? []).map { $0.sortOrder }.max() ?? -1) + 1
        for item in items {
            guard let id = item.itemIdentifier, !existing.contains(id) else { continue }
            let attachment = Attachment(kind: .photoAsset, label: "Photo")
            attachment.phAssetLocalID = id
            attachment.sortOrder = sortBase
            sortBase += 1
            owner.bind(attachment)
            modelContext.insert(attachment)
        }
        try? modelContext.save()
        pickerSelection = []
    }
}
