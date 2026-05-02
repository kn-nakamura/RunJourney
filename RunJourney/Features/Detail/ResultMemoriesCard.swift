import SwiftUI
import SwiftData

/// Result Detail（ScrollView ベース）で添付と写真を簡易プレビューとして見せるカード。
///
/// 編集の主舞台は `RaceResultEditView`（Form）の `AttachmentSection` / `PhotoLinkSection`。
/// 本ビューはあくまで参照系：写真サムネ＋添付サマリ＋ Edit ボタンで編集画面へ誘導する。
struct ResultMemoriesCard: View {
    @Bindable var result: RaceResult
    @Environment(\.modelContext) private var modelContext

    @State private var openingAttachment: Attachment? = nil

    private var photos: [Attachment] {
        (result.attachments ?? [])
            .filter { $0.kind == .photoAsset }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private var others: [Attachment] {
        (result.attachments ?? [])
            .filter { $0.kind != .photoAsset }
            .sorted {
                if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
                return $0.createdAt < $1.createdAt
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Memories")
                    .appText(.displaySm)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                NavigationLink {
                    RaceResultEditView(result: result)
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .appText(.bodyXs)
                        .foregroundStyle(.secondary)
                }
            }

            if photos.isEmpty && others.isEmpty {
                NavigationLink {
                    RaceResultEditView(result: result)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle")
                            .foregroundStyle(Color.accentPrimary)
                        Text("Add brochure, photos, or links from this race day")
                            .appText(.bodyXs)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            } else {
                if !photos.isEmpty {
                    photoStrip
                }
                if !others.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(others) { attachment in
                            Button {
                                openingAttachment = attachment
                            } label: {
                                AttachmentRow(attachment: attachment)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                            if attachment.id != others.last?.id {
                                Divider().background(Color.borderColor)
                            }
                        }
                    }
                    .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .sheet(item: $openingAttachment) { attachment in
            AttachmentEditSheet(attachment: attachment) {
                openingAttachment = nil
            }
        }
    }

    private var photoStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(photos) { att in
                    if let id = att.phAssetLocalID {
                        PhotoAssetThumbnail(localIdentifier: id, size: 100)
                    }
                }
            }
        }
    }
}
