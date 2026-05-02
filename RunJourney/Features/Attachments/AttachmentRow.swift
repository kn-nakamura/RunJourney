import SwiftUI

/// Attachments セクション内の 1 行。
/// 左: kind アイコン、中央: ラベル + 値プレビュー、右: chevron。
struct AttachmentRow: View {
    let attachment: Attachment

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: attachment.kind.systemImageName)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Color.accentPrimary)
                .frame(width: 28, height: 28)
                .background(Color.bgTertiary, in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(displayLabel)
                    .appText(.bodySmBold)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                if let preview = previewText {
                    Text(preview)
                        .appText(.bodyXs)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var displayLabel: String {
        attachment.label.isEmpty ? attachment.kind.displayName : attachment.label
    }

    private var previewText: String? {
        switch attachment.kind {
        case .text:
            let value = attachment.textValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return value.isEmpty ? "Empty note" : value
        case .url:
            let value = attachment.urlString?.trimmingCharacters(in: .whitespaces) ?? ""
            if value.isEmpty { return "Tap to add a URL" }
            if let host = URL(string: value)?.host { return host }
            return value
        case .pdf:
            return attachment.originalFilename ?? "PDF"
        case .image:
            return attachment.originalFilename ?? "Image"
        case .photoAsset:
            return "Linked from Photos"
        }
    }
}
