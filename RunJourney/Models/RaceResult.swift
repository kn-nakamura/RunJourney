import Foundation
import SwiftData

/// ユーザーの1回のレース参加結果。Race と多対1の関係を持つ。
///
/// `lapData` / `trackPoints` / `summary` は別@Modelにせず Codable JSON 配列として埋め込む:
/// - 1結果あたりトラックポイント数千件 → CloudKitで個別レコード化はオーバーヘッド過大
/// - SwiftDataは Codable プロパティを内部でJSONとして保存可能
@Model
final class RaceResult {
    var id: UUID = UUID()
    var raceDate: Date = Date.now
    var finishTimeSec: Double? = nil
    var isDNF: Bool = false
    var isDNS: Bool = false
    var isPB: Bool = false
    var isSB: Bool = false

    var weatherTempC: Double? = nil
    var weatherDescription: WeatherDescription? = nil
    var weatherCode: Int? = nil
    var condition: Condition? = nil

    var bibNumber: String? = nil
    var ageGroupPlace: Int? = nil
    var overallPlace: Int? = nil
    var totalFinishers: Int? = nil
    var comment: String? = nil

    var lapData: [LapData] = []
    var trackPoints: [TrackPoint] = []
    var summary: SummaryStats? = nil

    /// 紐付いた `PacePlan.id`。Soft FK にしている (= `@Relationship` を貼らない) のは、
    /// PacePlan を消したときに RaceResult まで cascade させたくないため。
    /// 表示時に `@Query` 結果から `id == linkedPacePlanId` で lookup する。
    var linkedPacePlanId: UUID? = nil

    // AI Review (Foundation Models / Apple Intelligence). On-device生成テキストをキャッシュ。
    var aiReviewText: String? = nil
    var aiReviewGeneratedAt: Date? = nil
    var aiReviewModelVersion: String? = nil

    var createdAt: Date = Date.now

    var race: Race? = nil

    @Relationship(deleteRule: .cascade, inverse: \Attachment.result)
    var attachments: [Attachment]? = []

    init(
        id: UUID = UUID(),
        race: Race? = nil,
        raceDate: Date = .now,
        finishTimeSec: Double? = nil
    ) {
        self.id = id
        self.race = race
        self.raceDate = raceDate
        self.finishTimeSec = finishTimeSec
        self.createdAt = .now
    }
}
