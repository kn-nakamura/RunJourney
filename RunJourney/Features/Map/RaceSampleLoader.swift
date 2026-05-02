import Foundation
import SwiftData

/// 開発用のデモ用サンプルレース投入ヘルパー。
/// 旧 `RaceMapView.addDummyRaceNearTokyo` を切り出して、Map 画面と Settings 画面の
/// 両方から呼べるようにしたもの。
///
/// 既存と同名のレースは重複追加しないので、何度押してもサンプル 8 件に揃う。
enum RaceSampleLoader {

    /// 投入対象のサンプル定義 (名前・カテゴリ・緯度・経度・都市名)。
    private static let samples: [(String, RaceCategory, Double, Double, String)] = [
        ("Tokyo Marathon",                .fullMarathon, 35.6909, 139.6917, "Tokyo"),
        ("Shonan International Marathon", .fullMarathon, 35.3220, 139.4811, "Fujisawa"),
        ("Osaka Marathon",                .fullMarathon, 34.6937, 135.5023, "Osaka"),
        ("Hokkaido Marathon",             .fullMarathon, 43.0667, 141.3500, "Sapporo"),
        ("Hasetsune Cup",                 .trail,        35.7375, 139.1453, "Tokyo"),
        ("Ome Marathon",                  .halfMarathon, 35.7878, 139.2756, "Ome"),
        ("Itabashi City Marathon",        .fullMarathon, 35.7611, 139.6833, "Itabashi"),
        ("UTMF",                          .ultraCustom,  35.4361, 138.7186, "Fujikawaguchiko"),
    ]

    /// 既存レースに無いものだけを `modelContext` に追加する。
    /// `existing` には現状の Race 配列を渡す (重複判定用)。
    @discardableResult
    static func loadJapanSamples(into modelContext: ModelContext, existing: [Race]) -> Int {
        let existingNames = Set(existing.map(\.name))
        var added = 0
        for sample in samples where !existingNames.contains(sample.0) {
            let race = Race(
                name: sample.0,
                category: sample.1,
                address: sample.4,
                city: sample.4,
                country: "Japan",
                lat: sample.2,
                lng: sample.3
            )
            modelContext.insert(race)
            added += 1
        }
        if added > 0 {
            try? modelContext.save()
        }
        return added
    }
}
