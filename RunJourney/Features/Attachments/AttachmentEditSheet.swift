import SwiftUI
import SwiftData
import QuickLook

/// 添付項目1件のエディタ（種別ごとに UI を出し分け）。
/// 共通: ラベル編集 + 削除。
struct AttachmentEditSheet: View {
    @Bindable var attachment: Attachment
    let onClose: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showQuickLook = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Label")
                            .appText(.bodyXs)
                            .foregroundStyle(.secondary)
                        TextField("Label", text: $attachment.label, prompt: Text(attachment.kind.displayName))
                    }
                } header: {
                    SectionHeader(title: attachment.kind.displayName)
                }

                bodySection

                Section {
                    Button(role: .destructive) {
                        delete()
                    } label: {
                        Label("Delete Attachment", systemImage: "trash")
                            .appText(.bodySmBold)
                    }
                }
            }
            .navigationTitle(attachment.label.isEmpty ? attachment.kind.displayName : attachment.label)
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        try? modelContext.save()
                        onClose()
                        dismiss()
                    }
                    .appText(.bodySmBold)
                }
            }
        }
    }

    @ViewBuilder
    private var bodySection: some View {
        switch attachment.kind {
        case .text:
            Section {
                TextEditor(text: $attachment.textValue.bound)
                    .frame(minHeight: 160)
            } header: {
                Text("Note")
                    .appText(.bodyXs)
                    .foregroundStyle(.secondary)
            }

        case .url:
            Section {
                TextField("https://...", text: $attachment.urlString.bound)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if let url = validURL {
                    Link(destination: url) {
                        Label("Open Link", systemImage: "safari")
                            .appText(.bodySmBold)
                    }
                }
            } header: {
                Text("URL")
                    .appText(.bodyXs)
                    .foregroundStyle(.secondary)
            }

        case .pdf:
            Section {
                if let fileURL = AttachmentStore.url(for: attachment.relativePath) {
                    VStack(alignment: .leading, spacing: 8) {
                        if let name = attachment.originalFilename {
                            Text(name)
                                .appText(.bodySm)
                                .foregroundStyle(Color.textPrimary)
                        }
                        if let size = attachment.byteSize {
                            Text(formatBytes(size))
                                .appText(.codeXs)
                                .foregroundStyle(.tertiary)
                        }
                        Button {
                            showQuickLook = true
                        } label: {
                            Label("Preview PDF", systemImage: "doc.text.magnifyingglass")
                                .appText(.bodySmBold)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.bgTertiary)
                        .foregroundStyle(Color.textPrimary)
                    }
                    .quickLookPreview($previewURL)
                    .onChange(of: showQuickLook) { _, isOn in
                        previewURL = isOn ? fileURL : nil
                    }
                } else {
                    Text("File not yet synced from another device")
                        .appText(.bodyXs)
                        .foregroundStyle(.tertiary)
                }
            } header: {
                Text("PDF")
                    .appText(.bodyXs)
                    .foregroundStyle(.secondary)
            }

        case .image:
            Section {
                if let url = AttachmentStore.url(for: attachment.relativePath) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 320)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        case .failure:
                            Text("Image not available")
                                .appText(.bodyXs)
                                .foregroundStyle(.tertiary)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Text("File not yet synced from another device")
                        .appText(.bodyXs)
                        .foregroundStyle(.tertiary)
                }
            } header: {
                Text("Image")
                    .appText(.bodyXs)
                    .foregroundStyle(.secondary)
            }

        case .photoAsset:
            Section {
                if let id = attachment.phAssetLocalID {
                    PhotoAssetThumbnail(localIdentifier: id, size: 240)
                        .frame(height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Text("No photo linked")
                        .appText(.bodyXs)
                        .foregroundStyle(.tertiary)
                }
            } header: {
                Text("Photo")
                    .appText(.bodyXs)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @State private var previewURL: URL? = nil

    private var validURL: URL? {
        guard let raw = attachment.urlString?.trimmingCharacters(in: .whitespaces),
              !raw.isEmpty,
              let url = URL(string: raw),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else { return nil }
        return url
    }

    private func delete() {
        if attachment.relativePath != nil {
            AttachmentStore.delete(attachment.relativePath)
        }
        modelContext.delete(attachment)
        try? modelContext.save()
        onClose()
        dismiss()
    }

    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
