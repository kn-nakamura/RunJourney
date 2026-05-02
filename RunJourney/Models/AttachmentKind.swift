import Foundation

/// Attachment が保持できる種別。
/// CloudKit 同期想定で String rawValue を持つ。
enum AttachmentKind: String, Codable, CaseIterable {
    case text        // 自由メモ
    case url         // 外部リンク
    case pdf         // ローカル保存 PDF
    case image       // ローカル保存画像（画面内に直接表示する画像）
    case photoAsset  // Photos.app の PHAsset.localIdentifier への参照（コピーしない）

    var systemImageName: String {
        switch self {
        case .text:       return "text.alignleft"
        case .url:        return "link"
        case .pdf:        return "doc.fill"
        case .image:      return "photo"
        case .photoAsset: return "photo.on.rectangle"
        }
    }

    var displayName: String {
        switch self {
        case .text:       return "Note"
        case .url:        return "Link"
        case .pdf:        return "PDF"
        case .image:      return "Image"
        case .photoAsset: return "Photo"
        }
    }
}
