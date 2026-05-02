import Foundation
import CoreLocation

/// TCX (Training Center XML) ファイルを解析する。
/// 標準の `XMLParser` (SAX) を使う。Garmin / TrainingPeaks 互換。
enum TCXParser {

    static func parse(data: Data) throws -> ParsedActivity {
        let parser = XMLParser(data: data)
        let delegate = TCXParserDelegate()
        parser.delegate = delegate
        parser.shouldProcessNamespaces = false

        guard parser.parse() else {
            let detail = parser.parserError?.localizedDescription ?? "Unknown XML error"
            throw ImportError.parseFailed(detail)
        }

        guard !delegate.rawTrackpoints.isEmpty else { throw ImportError.noTrackPoints }

        // 開始時刻: 最初のTrackpointのTime（Activity.IdをFallback）
        let startDate = delegate.rawTrackpoints.first?.time ?? delegate.activityId
        let startMs = startDate?.timeIntervalSince1970 ?? 0

        var points: [TrackPoint] = []
        points.reserveCapacity(delegate.rawTrackpoints.count)

        var cumulativeDistM = 0.0
        var prevLat: Double?
        var prevLng: Double?
        var prevTimeSec: Double?

        for rp in delegate.rawTrackpoints {
            guard let lat = rp.lat, let lng = rp.lng else { continue }
            let timeSec = (rp.time?.timeIntervalSince1970 ?? 0) - startMs

            if let pl = prevLat, let pn = prevLng {
                cumulativeDistM += ActivityMath.haversineMeters(lat1: pl, lon1: pn, lat2: lat, lon2: lng)
            }
            prevLat = lat
            prevLng = lng

            // TCX自体に DistanceMeters があれば優先
            let distanceM = (rp.distanceMeters ?? 0) > 0 ? rp.distanceMeters! : cumulativeDistM

            var speedMs: Double?
            if let prevT = prevTimeSec, let prev = points.last {
                let dt = timeSec - prevT
                let dd = distanceM - prev.distanceM
                if dt > 0 && dd > 0 { speedMs = dd / dt }
            }

            points.append(TrackPoint(
                timeSec: timeSec,
                distanceM: distanceM,
                lat: lat,
                lng: lng,
                altitudeM: rp.altitudeMeters,
                heartRate: rp.heartRate,
                speedMs: speedMs,
                cadence: rp.cadence,
                powerW: rp.powerW.map { Double($0) },
                temperatureC: rp.temperatureC
            ))
            prevTimeSec = timeSec
        }

        let laps = delegate.lapsRaw.enumerated().map { (idx, raw) -> LapData in
            LapData(
                lapIndex: idx + 1,
                distanceM: raw.distanceMeters ?? 0,
                timeSec: raw.totalTimeSeconds ?? 0,
                paceSecPerKm: (raw.distanceMeters ?? 0) > 0
                    ? (raw.totalTimeSeconds ?? 0) / ((raw.distanceMeters ?? 0) / 1000.0)
                    : 0,
                triggerMethod: raw.triggerMethod,
                avgHeartRate: raw.avgHeartRate,
                maxHeartRate: raw.maxHeartRate,
                avgCadence: raw.cadence,
                avgPowerW: raw.avgPowerW,
                maxPowerW: raw.maxPowerW,
                calories: raw.calories
            )
        }

        let summary = ActivityMath.buildSummaryStats(trackPoints: points, laps: laps)

        let endDate = delegate.rawTrackpoints.last?.time
        let finishSec: Double?
        if let last = points.last, last.timeSec > 0 {
            finishSec = last.timeSec
        } else if !laps.isEmpty {
            finishSec = laps.reduce(0) { $0 + $1.timeSec }
        } else {
            finishSec = nil
        }

        let startCoord = points.first.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) }
        let endCoord = points.last.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) }

        return ParsedActivity(
            trackPoints: points,
            laps: laps,
            summary: summary,
            startDate: startDate,
            endDate: endDate,
            finishTimeSec: finishSec,
            startCoordinate: startCoord,
            endCoordinate: endCoord
        )
    }
}

// MARK: - Delegate

private final class TCXParserDelegate: NSObject, XMLParserDelegate {

    struct RawTrackpoint {
        var time: Date?
        var lat: Double?
        var lng: Double?
        var altitudeMeters: Double?
        var distanceMeters: Double?
        var heartRate: Int?
        var cadence: Int?
        var powerW: Int?
        var temperatureC: Double?
    }

    struct RawLap {
        var totalTimeSeconds: Double?
        var distanceMeters: Double?
        var avgHeartRate: Int?
        var maxHeartRate: Int?
        var calories: Double?
        var cadence: Int?
        var avgPowerW: Double?
        var maxPowerW: Double?
        var triggerMethod: LapTrigger?
    }

    private(set) var activityId: Date?
    private(set) var rawTrackpoints: [RawTrackpoint] = []
    private(set) var lapsRaw: [RawLap] = []

    private var currentText = ""
    private var elementStack: [String] = []
    private var pendingTrackpoint: RawTrackpoint?
    private var pendingLap: RawLap?

    /// 名前空間プレフィックスを取り除いて lowercased する
    private func localName(_ name: String) -> String {
        if let colon = name.firstIndex(of: ":") {
            return String(name[name.index(after: colon)...])
        }
        return name
    }

    private var inActivityId: Bool {
        elementStack.suffix(2) == ["Activity", "Id"]
    }

    private var inHRBpmValue: Bool {
        guard elementStack.count >= 2 else { return false }
        let parent = elementStack[elementStack.count - 2]
        let current = elementStack.last!
        return current == "Value" && (parent == "HeartRateBpm" || parent == "AverageHeartRateBpm" || parent == "MaximumHeartRateBpm")
    }

    private var hrBpmContext: String? {
        guard elementStack.count >= 2 else { return nil }
        return elementStack[elementStack.count - 2]
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        let local = localName(elementName)
        elementStack.append(local)
        currentText = ""

        switch local {
        case "Lap":
            var lap = RawLap()
            if let tm = attributeDict["TriggerMethod"] {
                lap.triggerMethod = LapTrigger(rawValue: tm)
            }
            pendingLap = lap
        case "Trackpoint":
            pendingTrackpoint = RawTrackpoint()
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let local = localName(elementName)
        let trim = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Activity.Id (開始時刻)
        if inActivityId, !trim.isEmpty {
            activityId = ActivityMath.parseISODate(trim)
        }

        // HR Value はコンテキストで解釈
        if inHRBpmValue, let n = Int(trim) {
            switch hrBpmContext {
            case "HeartRateBpm":
                pendingTrackpoint?.heartRate = n
            case "AverageHeartRateBpm":
                pendingLap?.avgHeartRate = n
            case "MaximumHeartRateBpm":
                pendingLap?.maxHeartRate = n
            default: break
            }
        }

        // Trackpoint 内
        if pendingTrackpoint != nil {
            switch local {
            case "Time":
                pendingTrackpoint!.time = ActivityMath.parseISODate(trim)
            case "LatitudeDegrees":
                pendingTrackpoint!.lat = Double(trim)
            case "LongitudeDegrees":
                pendingTrackpoint!.lng = Double(trim)
            case "AltitudeMeters":
                pendingTrackpoint!.altitudeMeters = Double(trim)
            case "DistanceMeters":
                if elementStack.dropLast().last == "Trackpoint" {
                    pendingTrackpoint!.distanceMeters = Double(trim)
                }
            case "Cadence":
                if elementStack.dropLast().last == "Trackpoint" {
                    if let n = Int(trim) { pendingTrackpoint!.cadence = n }
                }
            case "Watts":
                if let n = Int(trim) { pendingTrackpoint!.powerW = n }
            case "RunCadence":
                if let n = Int(trim) { pendingTrackpoint!.cadence = n }
            case "Speed":
                // 一部TCX拡張に存在。speedMs として保持しないが将来のために
                break
            default:
                break
            }
        }

        // Lap 内（Trackpoint外のスカラー）
        if pendingLap != nil, pendingTrackpoint == nil {
            switch local {
            case "TotalTimeSeconds":
                pendingLap!.totalTimeSeconds = Double(trim)
            case "DistanceMeters":
                if elementStack.dropLast().last == "Lap" {
                    pendingLap!.distanceMeters = Double(trim)
                }
            case "Calories":
                pendingLap!.calories = Double(trim)
            case "Cadence":
                if elementStack.dropLast().last == "Lap" {
                    pendingLap!.cadence = Int(trim)
                }
            case "AvgWatts", "AveragePower":
                pendingLap!.avgPowerW = Double(trim)
            case "MaxWatts", "MaximumPower":
                pendingLap!.maxPowerW = Double(trim)
            default:
                break
            }
        }

        // クローズ処理
        switch local {
        case "Trackpoint":
            if let tp = pendingTrackpoint { rawTrackpoints.append(tp) }
            pendingTrackpoint = nil
        case "Lap":
            if let lap = pendingLap { lapsRaw.append(lap) }
            pendingLap = nil
        default:
            break
        }

        if !elementStack.isEmpty { elementStack.removeLast() }
        currentText = ""
    }
}
