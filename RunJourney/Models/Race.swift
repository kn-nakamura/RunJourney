import Foundation
import SwiftData
import CoreLocation

/// マラソン大会のマスター情報。複数のRaceResultから参照される。
///
/// **CloudKit対応の制約**:
/// - `@Attribute(.unique)` は CloudKit-backed store では使えないので使用しない
/// - 全プロパティにデフォルト値を持たせる
@Model
final class Race {
    var id: UUID = UUID()
    var name: String = ""
    var category: RaceCategory = RaceCategory.fullMarathon
    var distanceKm: Double? = nil
    var address: String? = nil
    var city: String? = nil
    var country: String = "Japan"
    var lat: Double = 0
    var lng: Double = 0
    var websiteURL: String? = nil
    var logoURL: String? = nil
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \RaceResult.race)
    var results: [RaceResult]? = []

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    init(
        id: UUID = UUID(),
        name: String = "",
        category: RaceCategory = .fullMarathon,
        distanceKm: Double? = nil,
        address: String? = nil,
        city: String? = nil,
        country: String = "Japan",
        lat: Double = 0,
        lng: Double = 0,
        websiteURL: String? = nil,
        logoURL: String? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.distanceKm = distanceKm ?? category.defaultDistanceKm
        self.address = address
        self.city = city
        self.country = country
        self.lat = lat
        self.lng = lng
        self.websiteURL = websiteURL
        self.logoURL = logoURL
        self.createdAt = .now
    }
}
