import Foundation
import CoreLocation
#if canImport(WeatherKit)
import WeatherKit
#endif

/// 1時間ごとの天気サンプル。`WeatherSection` のスライダーで選択する単位。
struct HourlyWeather: Hashable, Identifiable {
    let hour: Date
    let tempC: Double
    let description: WeatherDescription
    let code: Int
    var id: Date { hour }
}

enum WeatherSource: String {
    case weatherKit = "WeatherKit"
    case openMeteo  = "Open-Meteo"
}

struct HourlyResult {
    let hours: [HourlyWeather]
    let source: WeatherSource
}

/// Apple WeatherKit を優先、失敗または古い日付の場合は Open-Meteo Archive にフォールバック。
///
/// WeatherKit 注意点:
/// - Apple Developer Program 加入 + entitlement (`com.apple.developer.weatherkit`) 必須
/// - 過去データは概ね数年程度。それより古い日付は hourly 配列が空 / エラーになる
/// - 月 50 万コール無料
///
/// Open-Meteo 注意点:
/// - キー不要 / 無料 / 過去データに強い
/// - 直近 5 日程度はパブリッシュラグあり → WeatherKit を先に試す意味がある
enum WeatherFetcher {

    enum FetchError: LocalizedError {
        case noData
        case decoding
        var errorDescription: String? {
            switch self {
            case .noData:   return "No weather data available for this date and location."
            case .decoding: return "Failed to decode weather response."
            }
        }
    }

    /// 指定座標・日付の 0〜23時を返す。可能な限り WeatherKit を優先。
    static func fetchHourly(at coord: CLLocationCoordinate2D, on date: Date) async throws -> HourlyResult {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            throw FetchError.noData
        }

        // 1. WeatherKit を試す
        #if canImport(WeatherKit)
        do {
            let hours = try await fetchWeatherKit(coord: coord, start: dayStart, end: dayEnd)
            if !hours.isEmpty {
                return HourlyResult(hours: hours, source: .weatherKit)
            }
        } catch {
            // フォールバックへ
        }
        #endif

        // 2. Open-Meteo Archive にフォールバック
        let hours = try await fetchOpenMeteo(coord: coord, dayStart: dayStart)
        guard !hours.isEmpty else { throw FetchError.noData }
        return HourlyResult(hours: hours, source: .openMeteo)
    }

    // MARK: - WeatherKit

    #if canImport(WeatherKit)
    private static func fetchWeatherKit(
        coord: CLLocationCoordinate2D,
        start: Date,
        end: Date
    ) async throws -> [HourlyWeather] {
        let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        let weather = try await WeatherService.shared.weather(
            for: location,
            including: .hourly(startDate: start, endDate: end)
        )
        return weather.forecast.map { hour in
            let tempC = hour.temperature.converted(to: .celsius).value
            let (desc, code) = mapWeatherKitCondition(hour.condition)
            return HourlyWeather(
                hour: hour.date,
                tempC: tempC,
                description: desc,
                code: code
            )
        }
    }

    /// `WeatherCondition` を既存 `WeatherDescription` + 代表 WMO code に変換。
    /// iOS バージョンで増減するケースは raw 文字列ベースで分類して `@unknown default` で受ける。
    private static func mapWeatherKitCondition(_ condition: WeatherCondition) -> (WeatherDescription, Int) {
        let raw = String(describing: condition).lowercased()
        if raw.contains("snow") || raw.contains("sleet") || raw.contains("blizzard")
            || raw.contains("flurries") || raw.contains("hail") || raw.contains("wintry") {
            return (.snowy, 73)
        }
        if raw.contains("rain") || raw.contains("drizzle") || raw.contains("thunder")
            || raw.contains("storm") || raw.contains("hurricane") || raw.contains("tropical")
            || raw.contains("shower") {
            return (.rainy, 63)
        }
        if raw.contains("wind") || raw.contains("breez") {
            return (.windy, 3)
        }
        if raw.contains("clear") || raw == "hot" || raw.contains("sun") {
            return (.sunny, 0)
        }
        // partlyCloudy / cloudy / mostlyCloudy / foggy / haze / smoky など
        return (.cloudy, 3)
    }
    #endif

    // MARK: - Open-Meteo Archive

    private static func fetchOpenMeteo(
        coord: CLLocationCoordinate2D,
        dayStart: Date
    ) async throws -> [HourlyWeather] {
        let isoFormatter = DateFormatter()
        isoFormatter.locale = Locale(identifier: "en_US_POSIX")
        isoFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = isoFormatter.string(from: dayStart)

        var components = URLComponents(string: "https://archive-api.open-meteo.com/v1/archive")!
        components.queryItems = [
            .init(name: "latitude", value: String(coord.latitude)),
            .init(name: "longitude", value: String(coord.longitude)),
            .init(name: "start_date", value: dateString),
            .init(name: "end_date", value: dateString),
            .init(name: "hourly", value: "temperature_2m,weathercode"),
            .init(name: "timezone", value: "auto"),
        ]
        guard let url = components.url else { throw FetchError.noData }

        let (data, _) = try await URLSession.shared.data(from: url)
        guard let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hourly = payload["hourly"] as? [String: Any],
              let times = hourly["time"] as? [String],
              let temps = hourly["temperature_2m"] as? [Double],
              let codes = hourly["weathercode"] as? [Int]
        else { throw FetchError.decoding }

        let hourFormatter = DateFormatter()
        hourFormatter.locale = Locale(identifier: "en_US_POSIX")
        hourFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        // Open-Meteo の `timezone=auto` は応答 hourly.time をローカルタイム文字列で返すので、
        // TimeZone を current に設定して同じローカル時刻として解釈する。
        hourFormatter.timeZone = TimeZone.current

        var result: [HourlyWeather] = []
        for (index, time) in times.enumerated() {
            guard index < temps.count, index < codes.count,
                  let date = hourFormatter.date(from: time) else { continue }
            let code = codes[index]
            result.append(HourlyWeather(
                hour: date,
                tempC: temps[index],
                description: WeatherDescription.from(wmoCode: code),
                code: code
            ))
        }
        return result
    }
}
