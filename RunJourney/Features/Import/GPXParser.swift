import Foundation
import CoreLocation

/// GPX (GPS Exchange Format) ファイルを解析する。
/// 標準の `XMLParser` (SAX) を delegate で walk する。namespace prefix (gpxtpx:hr 等) には localname で対応。
enum GPXParser {

    static func parse(data: Data) throws -> ParsedActivity {
        let parser = XMLParser(data: data)
        let delegate = GPXParserDelegate()
        parser.delegate = delegate
        parser.shouldProcessNamespaces = false
        parser.shouldReportNamespacePrefixes = false

        guard parser.parse() else {
            let detail = parser.parserError?.localizedDescription ?? "不明なXMLエラー"
            throw ImportError.parseFailed(detail)
        }

        let raw = delegate.rawPoints
        guard !raw.isEmpty else { throw ImportError.noTrackPoints }

        let startDate = raw.first?.time
        let startMs = startDate?.timeIntervalSince1970 ?? 0

        var points: [TrackPoint] = []
        points.reserveCapacity(raw.count)

        var cumulativeDistM = 0.0
        var prevLat: Double?
        var prevLng: Double?
        var prevTimeSec: Double?

        for rp in raw {
            let timeSec = (rp.time?.timeIntervalSince1970 ?? 0) - startMs

            if let pl = prevLat, let pn = prevLng {
                cumulativeDistM += ActivityMath.haversineMeters(lat1: pl, lon1: pn, lat2: rp.lat, lon2: rp.lng)
            }
            prevLat = rp.lat
            prevLng = rp.lng

            // 速度: 直前点との微分
            var speedMs: Double?
            if let prevT = prevTimeSec, let prev = points.last {
                let dt = timeSec - prevT
                let dd = cumulativeDistM - prev.distanceM
                if dt > 0 && dd > 0 { speedMs = dd / dt }
            }

            points.append(TrackPoint(
                timeSec: timeSec,
                distanceM: cumulativeDistM,
                lat: rp.lat,
                lng: rp.lng,
                altitudeM: rp.altitude,
                heartRate: rp.heartRate,
                speedMs: speedMs,
                cadence: rp.cadence,
                temperatureC: rp.temperature
            ))
            prevTimeSec = timeSec
        }

        let laps = buildLapsFromSegments(delegate.segments, parsedPoints: points)
        let summary = ActivityMath.buildSummaryStats(trackPoints: points, laps: laps)

        let endDate = raw.last?.time
        let finishSec = points.last?.timeSec
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

    /// trkseg を1ラップとして集計（GPXは明示的なラップを持たないことが多いため）。
    private static func buildLapsFromSegments(
        _ segments: [GPXParserDelegate.SegmentRange],
        parsedPoints: [TrackPoint]
    ) -> [LapData] {
        guard !segments.isEmpty, parsedPoints.count >= 2 else {
            // セグメントが1つしか無い・無い場合は全体を1ラップとして扱う
            if let last = parsedPoints.last, last.distanceM > 0, last.timeSec > 0 {
                return [LapData(
                    lapIndex: 1,
                    distanceM: last.distanceM,
                    timeSec: last.timeSec,
                    paceSecPerKm: last.timeSec / (last.distanceM / 1000.0),
                    triggerMethod: .sessionEnd
                )]
            }
            return []
        }

        var laps: [LapData] = []
        for (idx, segment) in segments.enumerated() {
            guard segment.start < parsedPoints.count, segment.end < parsedPoints.count, segment.end > segment.start else { continue }
            let s = parsedPoints[segment.start]
            let e = parsedPoints[segment.end]
            let dist = e.distanceM - s.distanceM
            let time = e.timeSec - s.timeSec
            guard dist > 0, time > 0 else { continue }

            let segPoints = parsedPoints[segment.start...segment.end]
            let validHRs = segPoints.compactMap { $0.heartRate }.filter { $0 > 0 }
            let altitudes = segPoints.compactMap { $0.altitudeM }
            var gain = 0.0, loss = 0.0
            for i in 1..<altitudes.count {
                let d = altitudes[i] - altitudes[i - 1]
                if d > 0 { gain += d } else { loss += -d }
            }

            laps.append(LapData(
                lapIndex: idx + 1,
                distanceM: dist,
                timeSec: time,
                paceSecPerKm: time / (dist / 1000.0),
                triggerMethod: .manual,
                avgHeartRate: validHRs.isEmpty ? nil : Int(Double(validHRs.reduce(0, +)) / Double(validHRs.count)),
                maxHeartRate: validHRs.max(),
                elevationGainM: altitudes.isEmpty ? nil : gain,
                elevationLossM: altitudes.isEmpty ? nil : loss
            ))
        }
        return laps
    }
}

// MARK: - Delegate

private final class GPXParserDelegate: NSObject, XMLParserDelegate {

    struct RawPoint {
        var lat: Double
        var lng: Double
        var time: Date?
        var altitude: Double?
        var heartRate: Int?
        var cadence: Int?
        var temperature: Double?
    }

    /// trkseg を [start, end] の index 範囲で記録（segmentEnd時に確定）
    struct SegmentRange {
        var start: Int
        var end: Int
    }

    private(set) var rawPoints: [RawPoint] = []
    private(set) var segments: [SegmentRange] = []

    private var currentText = ""
    private var pendingPoint: RawPoint?
    private var segmentStartIndex: Int?

    /// 名前空間プレフィックス除去
    private func localName(_ name: String) -> String {
        if let colon = name.firstIndex(of: ":") {
            return String(name[name.index(after: colon)...]).lowercased()
        }
        return name.lowercased()
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentText = ""
        let local = localName(elementName)

        switch local {
        case "trkseg":
            segmentStartIndex = rawPoints.count
        case "trkpt":
            let lat = Double(attributeDict["lat"] ?? "") ?? 0
            let lng = Double(attributeDict["lon"] ?? "") ?? 0
            pendingPoint = RawPoint(lat: lat, lng: lng)
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

        if pendingPoint != nil {
            switch local {
            case "ele":
                pendingPoint!.altitude = Double(trim)
            case "time":
                pendingPoint!.time = ActivityMath.parseISODate(trim)
            case "hr", "heartrate":
                if let n = Double(trim), n > 0 {
                    pendingPoint!.heartRate = Int(n)
                }
            case "cad", "cadence":
                if let n = Double(trim), n > 0 {
                    pendingPoint!.cadence = Int(n)
                }
            case "atemp", "temp", "temperature":
                pendingPoint!.temperature = Double(trim)
            default:
                break
            }
        }

        if local == "trkpt", let pt = pendingPoint {
            rawPoints.append(pt)
            pendingPoint = nil
        } else if local == "trkseg", let start = segmentStartIndex {
            let endIdx = max(start, rawPoints.count - 1)
            if endIdx > start {
                segments.append(SegmentRange(start: start, end: endIdx))
            }
            segmentStartIndex = nil
        }

        currentText = ""
    }
}
