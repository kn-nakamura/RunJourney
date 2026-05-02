import Foundation

/// Race / RaceResult を `AttachmentSection` などのジェネリック View から扱うためのプロトコル。
///
/// `Attachment.race` / `Attachment.result` のどちらに紐付けるかは実装側で決まるので、
/// `bind(_:)` で新規 Attachment に正しい relationship を張る役を持たせる。
@MainActor
protocol AttachmentOwner: AnyObject {
    var id: UUID { get }
    var attachments: [Attachment]? { get set }
    /// 新規 Attachment を自分に紐付ける。
    func bind(_ attachment: Attachment)
}

extension Race: AttachmentOwner {
    func bind(_ attachment: Attachment) {
        attachment.race = self
    }
}

extension RaceResult: AttachmentOwner {
    func bind(_ attachment: Attachment) {
        attachment.result = self
    }
}
