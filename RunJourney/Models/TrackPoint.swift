import Foundation
import CoreLocation

/// 1ポイント分の時系列計測値。サンプリング後で `RaceResult.trackPoints` に入る。
/// 4時間マラソンを1Hzで保存すると14400点 → CloudKit 1レコード/ポイントは現実的でないため、
/// `RaceResult` に Codable JSON として配列で埋め込む。表示時は必要に応じて間引いて使う。
struct TrackPoint: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var timeSec: Double
    var distanceM: Double
    var lat: Double
    var lng: Double

    var altitudeM: Double?
    var heartRate: Int?
    var speedMs: Double?
    var cadence: Int?
    var powerW: Double?
    var temperatureC: Double?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    init(
        timeSec: Double,
        distanceM: Double,
        lat: Double,
        lng: Double,
        altitudeM: Double? = nil,
        heartRate: Int? = nil,
        speedMs: Double? = nil,
        cadence: Int? = nil,
        powerW: Double? = nil,
        temperatureC: Double? = nil
    ) {
        self.timeSec = timeSec
        self.distanceM = distanceM
        self.lat = lat
        self.lng = lng
        self.altitudeM = altitudeM
        self.heartRate = heartRate
        self.speedMs = speedMs
        self.cadence = cadence
        self.powerW = powerW
        self.temperatureC = temperatureC
    }
}
