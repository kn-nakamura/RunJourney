import Foundation
import CoreLocation

/// Garmin FIT (Flexible and Interoperable Data Transfer) ファイルを解析する。
/// 外部依存ゼロのDIY実装。FITフォーマット仕様 v2.x に準拠。
///
/// **対応範囲（MVP）**:
/// - File header (12 / 14 byte)
/// - Definition Message (Normal Header)
/// - Data Message (Normal Header)
/// - Compressed Timestamp Header
/// - Little-endian / Big-endian の両アーキテクチャ
/// - Developer fields のスキップ
/// - Global message: record (20), lap (19), session (18) の主要フィールド
///
/// **未対応**:
/// - 複数 file の chained FIT
/// - ファイルCRC検証
enum FITParser {

    static func parse(data: Data) throws -> ParsedActivity {
        var reader = FITByteReader(data: data)
        try reader.validateHeader()

        var definitions: [Int: FITDefinition] = [:]
        var records: [FITRecordPoint] = []
        var laps: [FITLapEntry] = []
        var lastTimestamp: UInt32 = 0  // for compressed timestamp header

        while reader.offset < reader.dataEndOffset {
            guard let recHeader = reader.readUInt8() else { break }

            if recHeader & 0x80 != 0 {
                // Compressed Timestamp Header: bit7=1, bit6-5=local_message_type, bit4-0=offset
                let localType = Int((recHeader >> 5) & 0x03)
                let timeOffset = UInt32(recHeader & 0x1F)
                guard let def = definitions[localType] else {
                    // 定義無しのデータは読み飛ばし不可、エラーにせず終了
                    break
                }
                // 5-bit offset を加算（5-bit roll-over考慮）
                if timeOffset >= (lastTimestamp & 0x1F) {
                    lastTimestamp = (lastTimestamp & 0xFFFFFFE0) + timeOffset
                } else {
                    lastTimestamp = (lastTimestamp & 0xFFFFFFE0) + 0x20 + timeOffset
                }
                try processDataMessage(
                    def: def,
                    reader: &reader,
                    forcedTimestamp: lastTimestamp,
                    records: &records,
                    laps: &laps,
                    lastTimestamp: &lastTimestamp
                )
            } else {
                // Normal Header
                let isDefinition = (recHeader & 0x40) != 0
                let hasDevData = (recHeader & 0x20) != 0
                let localType = Int(recHeader & 0x0F)

                if isDefinition {
                    let def = try readDefinition(reader: &reader, hasDevData: hasDevData)
                    definitions[localType] = def
                } else {
                    guard let def = definitions[localType] else {
                        throw ImportError.parseFailed("FIT: data message without definition (localType=\(localType))")
                    }
                    try processDataMessage(
                        def: def,
                        reader: &reader,
                        forcedTimestamp: nil,
                        records: &records,
                        laps: &laps,
                        lastTimestamp: &lastTimestamp
                    )
                }
            }
        }

        guard !records.isEmpty else { throw ImportError.noTrackPoints }

        return convertToParsedActivity(records: records, laps: laps)
    }

    // MARK: - Definition message

    private static func readDefinition(reader: inout FITByteReader, hasDevData: Bool) throws -> FITDefinition {
        guard reader.skip(1) else { throw ImportError.parseFailed("FIT: truncated definition (reserved)") }
        guard let archByte = reader.readUInt8() else { throw ImportError.parseFailed("FIT: truncated definition (arch)") }
        let isLittleEndian = archByte == 0
        guard let globalMsgNum = reader.readUInt16(littleEndian: isLittleEndian) else {
            throw ImportError.parseFailed("FIT: truncated definition (global msg)")
        }
        guard let numFields = reader.readUInt8() else {
            throw ImportError.parseFailed("FIT: truncated definition (num fields)")
        }

        var fields: [FITFieldDef] = []
        fields.reserveCapacity(Int(numFields))
        for _ in 0..<numFields {
            guard let fieldNum = reader.readUInt8(),
                  let size = reader.readUInt8(),
                  let baseType = reader.readUInt8() else {
                throw ImportError.parseFailed("FIT: truncated field definition")
            }
            fields.append(FITFieldDef(fieldNumber: fieldNum, size: Int(size), baseType: baseType))
        }

        // Developer fields (skip)
        var devFields: [FITFieldDef] = []
        if hasDevData {
            guard let numDev = reader.readUInt8() else { throw ImportError.parseFailed("FIT: truncated dev field count") }
            for _ in 0..<numDev {
                guard let n = reader.readUInt8(),
                      let s = reader.readUInt8(),
                      let i = reader.readUInt8() else {
                    throw ImportError.parseFailed("FIT: truncated dev field")
                }
                devFields.append(FITFieldDef(fieldNumber: n, size: Int(s), baseType: i))
            }
        }

        return FITDefinition(
            globalMessageNumber: Int(globalMsgNum),
            isLittleEndian: isLittleEndian,
            fields: fields,
            devFields: devFields
        )
    }

    // MARK: - Data message

    private static func processDataMessage(
        def: FITDefinition,
        reader: inout FITByteReader,
        forcedTimestamp: UInt32?,
        records: inout [FITRecordPoint],
        laps: inout [FITLapEntry],
        lastTimestamp: inout UInt32
    ) throws {
        // フィールド値マップ: fieldNumber → 生バイト → 解釈値
        var values: [Int: FITValue] = [:]

        for field in def.fields {
            guard let valueData = reader.readBytes(field.size) else {
                throw ImportError.parseFailed("FIT: truncated data field")
            }
            if let v = decodeFITValue(data: valueData, baseType: field.baseType, isLE: def.isLittleEndian) {
                values[Int(field.fieldNumber)] = v
            }
        }
        // dev fields skip
        for field in def.devFields {
            _ = reader.skip(field.size)
        }

        // Timestamp 抽出（field 253）
        let timestamp: UInt32?
        if let forced = forcedTimestamp {
            timestamp = forced
        } else if case let .uint32(ts) = values[253] {
            lastTimestamp = ts
            timestamp = ts
        } else {
            timestamp = nil
        }

        switch def.globalMessageNumber {
        case 20: // record
            if let rec = buildRecordPoint(values: values, timestamp: timestamp) {
                records.append(rec)
            }
        case 19: // lap
            if let lap = buildLapEntry(values: values, timestamp: timestamp) {
                laps.append(lap)
            }
        default:
            // session(18), event(21), file_id(0), activity(34) などはスキップ
            break
        }
    }

    // MARK: - Build typed entries

    private static func buildRecordPoint(values: [Int: FITValue], timestamp: UInt32?) -> FITRecordPoint? {
        guard let ts = timestamp else { return nil }
        guard case let .sint32(latRaw) = values[0] else { return nil }
        guard case let .sint32(lngRaw) = values[1] else { return nil }
        let lat = Double(latRaw) * semicircleToDegree
        let lng = Double(lngRaw) * semicircleToDegree

        // Altitude: 78=enhanced_altitude (uint32, scale 5, offset 500) を優先
        let altitude: Double? = {
            if case let .uint32(raw) = values[78] {
                return Double(raw) / 5.0 - 500.0
            }
            if case let .uint16(raw) = values[2] {
                return Double(raw) / 5.0 - 500.0
            }
            return nil
        }()

        let heartRate: Int? = {
            if case let .uint8(v) = values[3], v > 0 { return Int(v) }
            return nil
        }()

        let cadence: Int? = {
            if case let .uint8(v) = values[4], v > 0 { return Int(v) }
            return nil
        }()

        let distance: Double? = {
            if case let .uint32(v) = values[5] { return Double(v) / 100.0 }
            return nil
        }()

        let speed: Double? = {
            if case let .uint32(v) = values[73] { return Double(v) / 1000.0 }
            if case let .uint16(v) = values[6] { return Double(v) / 1000.0 }
            return nil
        }()

        let power: Double? = {
            if case let .uint16(v) = values[7] { return Double(v) }
            return nil
        }()

        let temperature: Double? = {
            if case let .sint8(v) = values[13] { return Double(v) }
            return nil
        }()

        return FITRecordPoint(
            timestamp: ts,
            lat: lat,
            lng: lng,
            altitude: altitude,
            distance: distance,
            heartRate: heartRate,
            cadence: cadence,
            speed: speed,
            power: power,
            temperature: temperature
        )
    }

    private static func buildLapEntry(values: [Int: FITValue], timestamp: UInt32?) -> FITLapEntry? {
        // FIT lap message field index (Garmin SDK Profile.xlsx):
        //   7  total_elapsed_time (uint32, scale 1000, sec)
        //   9  total_distance     (uint32, scale 100,  m)
        //   11 total_calories     (uint16, kcal)
        //   15 avg_heart_rate     (uint8,  bpm)
        //   16 max_heart_rate     (uint8,  bpm)
        //   17 avg_cadence        (uint8,  rpm)
        //   18 max_cadence        (uint8,  rpm)
        //   19 avg_power          (uint16, watts)
        //   20 max_power          (uint16, watts)
        //   21 total_ascent       (uint16, m)
        //   22 total_descent      (uint16, m)
        //   24 lap_trigger        (enum)
        let totalElapsed: Double? = {
            if case let .uint32(v) = values[7] { return Double(v) / 1000.0 }
            return nil
        }()
        let totalDistance: Double? = {
            if case let .uint32(v) = values[9] { return Double(v) / 100.0 }
            return nil
        }()
        guard let time = totalElapsed, let dist = totalDistance, time > 0, dist > 0 else { return nil }

        let avgHR: Int? = { if case let .uint8(v) = values[15], v > 0 { return Int(v) } else { return nil } }()
        let maxHR: Int? = { if case let .uint8(v) = values[16], v > 0 { return Int(v) } else { return nil } }()
        let avgCadence: Int? = { if case let .uint8(v) = values[17], v > 0 { return Int(v) } else { return nil } }()
        let maxCadence: Int? = { if case let .uint8(v) = values[18], v > 0 { return Int(v) } else { return nil } }()
        let calories: Double? = { if case let .uint16(v) = values[11] { return Double(v) } else { return nil } }()
        let avgPower: Double? = { if case let .uint16(v) = values[19] { return Double(v) } else { return nil } }()
        let maxPower: Double? = { if case let .uint16(v) = values[20] { return Double(v) } else { return nil } }()
        let totalAscent: Double? = { if case let .uint16(v) = values[21] { return Double(v) } else { return nil } }()
        let totalDescent: Double? = { if case let .uint16(v) = values[22] { return Double(v) } else { return nil } }()
        let triggerEnum: UInt8? = { if case let .uint8(v) = values[24] { return v } else { return nil } }()

        return FITLapEntry(
            timestamp: timestamp,
            totalTimeSec: time,
            totalDistanceM: dist,
            avgHeartRate: avgHR,
            maxHeartRate: maxHR,
            avgCadence: avgCadence,
            maxCadence: maxCadence,
            calories: calories,
            avgPowerW: avgPower,
            maxPowerW: maxPower,
            elevationGainM: totalAscent,
            elevationLossM: totalDescent,
            trigger: triggerEnum.flatMap { fitLapTrigger(rawEnum: $0) }
        )
    }

    private static func fitLapTrigger(rawEnum: UInt8) -> LapTrigger? {
        switch rawEnum {
        case 0: return .manual
        case 1: return .time
        case 2: return .distance
        case 3: return .location  // position_start
        case 4: return .location  // position_lap
        case 5: return .location
        case 6: return .location
        case 7: return .sessionEnd  // fitness_equipment 用途的に終了扱い
        default: return nil
        }
    }

    // MARK: - ParsedActivity assembly

    private static func convertToParsedActivity(records: [FITRecordPoint], laps: [FITLapEntry]) -> ParsedActivity {
        let firstTs = records.first!.timestamp
        let startDate = Date(timeIntervalSince1970: TimeInterval(firstTs) + fitEpochOffset)

        var trackPoints: [TrackPoint] = []
        trackPoints.reserveCapacity(records.count)
        for r in records {
            let timeSec = Double(r.timestamp) - Double(firstTs)
            trackPoints.append(TrackPoint(
                timeSec: timeSec,
                distanceM: r.distance ?? 0,
                lat: r.lat,
                lng: r.lng,
                altitudeM: r.altitude,
                heartRate: r.heartRate,
                speedMs: r.speed,
                cadence: r.cadence,
                powerW: r.power,
                temperatureC: r.temperature
            ))
        }

        // distance が無い場合は haversine で再計算
        let needsDistance = trackPoints.allSatisfy { $0.distanceM == 0 }
        if needsDistance, trackPoints.count >= 2 {
            var cumulative = 0.0
            for i in 1..<trackPoints.count {
                let p = trackPoints[i - 1]
                let c = trackPoints[i]
                cumulative += ActivityMath.haversineMeters(lat1: p.lat, lon1: p.lng, lat2: c.lat, lon2: c.lng)
                trackPoints[i].distanceM = cumulative
            }
        }

        let convertedLaps = laps.enumerated().map { (idx, lap) in
            LapData(
                lapIndex: idx + 1,
                distanceM: lap.totalDistanceM,
                timeSec: lap.totalTimeSec,
                paceSecPerKm: lap.totalDistanceM > 0 ? lap.totalTimeSec / (lap.totalDistanceM / 1000.0) : 0,
                triggerMethod: lap.trigger,
                avgHeartRate: lap.avgHeartRate,
                maxHeartRate: lap.maxHeartRate,
                elevationGainM: lap.elevationGainM,
                elevationLossM: lap.elevationLossM,
                avgCadence: lap.avgCadence,
                maxCadence: lap.maxCadence,
                avgPowerW: lap.avgPowerW,
                maxPowerW: lap.maxPowerW,
                calories: lap.calories
            )
        }

        let summary = ActivityMath.buildSummaryStats(trackPoints: trackPoints, laps: convertedLaps)

        let endDate: Date? = trackPoints.last.map {
            Date(timeIntervalSince1970: TimeInterval(firstTs) + $0.timeSec + fitEpochOffset)
        }

        let finishSec: Double? = trackPoints.last?.timeSec ?? convertedLaps.reduce(0) { $0 + $1.timeSec }
        let startCoord = trackPoints.first.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) }
        let endCoord = trackPoints.last.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) }

        return ParsedActivity(
            trackPoints: trackPoints,
            laps: convertedLaps,
            summary: summary,
            startDate: startDate,
            endDate: endDate,
            finishTimeSec: finishSec,
            startCoordinate: startCoord,
            endCoordinate: endCoord
        )
    }
}

// MARK: - Constants

private let semicircleToDegree: Double = 180.0 / 2147483648.0  // 180 / 2^31
/// FIT epoch (1989-12-31 00:00 UTC) → Unix epoch (1970-01-01 00:00 UTC) のオフセット秒
private let fitEpochOffset: TimeInterval = 631_065_600

// MARK: - Internal types

private struct FITDefinition {
    let globalMessageNumber: Int
    let isLittleEndian: Bool
    let fields: [FITFieldDef]
    let devFields: [FITFieldDef]
}

private struct FITFieldDef {
    let fieldNumber: UInt8
    let size: Int
    let baseType: UInt8
}

private enum FITValue {
    case uint8(UInt8)
    case sint8(Int8)
    case uint16(UInt16)
    case sint16(Int16)
    case uint32(UInt32)
    case sint32(Int32)
    case uint64(UInt64)
    case sint64(Int64)
    case float32(Float)
    case float64(Double)
    case string(String)
    case bytes(Data)
}

private struct FITRecordPoint {
    let timestamp: UInt32
    let lat: Double
    let lng: Double
    let altitude: Double?
    let distance: Double?
    let heartRate: Int?
    let cadence: Int?
    let speed: Double?
    let power: Double?
    let temperature: Double?
}

private struct FITLapEntry {
    let timestamp: UInt32?
    let totalTimeSec: Double
    let totalDistanceM: Double
    let avgHeartRate: Int?
    let maxHeartRate: Int?
    let avgCadence: Int?
    let maxCadence: Int?
    let calories: Double?
    let avgPowerW: Double?
    let maxPowerW: Double?
    let elevationGainM: Double?
    let elevationLossM: Double?
    let trigger: LapTrigger?
}

// MARK: - Byte reader

private struct FITByteReader {
    let data: Data
    var offset: Int
    var dataEndOffset: Int

    init(data: Data) {
        self.data = data
        self.offset = 0
        self.dataEndOffset = data.count  // validateHeader で更新
    }

    mutating func validateHeader() throws {
        guard data.count >= 14 else {
            throw ImportError.parseFailed("FIT file too small (\(data.count) bytes)")
        }
        let headerSize = Int(data[0])
        guard headerSize == 12 || headerSize == 14 else {
            throw ImportError.parseFailed("Invalid FIT header size: \(headerSize)")
        }
        let magic = data.subdata(in: 8..<12)
        guard magic == Data(".FIT".utf8) else {
            throw ImportError.parseFailed("Not a FIT file (magic mismatch)")
        }
        let dataSize = data.subdata(in: 4..<8).withUnsafeBytes {
            $0.load(as: UInt32.self).littleEndian
        }
        offset = headerSize
        dataEndOffset = headerSize + Int(dataSize)
        guard dataEndOffset <= data.count else {
            throw ImportError.parseFailed("FIT data size out of range")
        }
    }

    mutating func readUInt8() -> UInt8? {
        guard offset < data.count else { return nil }
        let v = data[offset]
        offset += 1
        return v
    }

    mutating func readUInt16(littleEndian: Bool) -> UInt16? {
        guard offset + 2 <= data.count else { return nil }
        let bytes = data.subdata(in: offset..<offset + 2)
        offset += 2
        let raw = bytes.withUnsafeBytes { $0.load(as: UInt16.self) }
        return littleEndian ? raw.littleEndian : raw.bigEndian
    }

    mutating func readBytes(_ count: Int) -> Data? {
        guard offset + count <= data.count else { return nil }
        let bytes = data.subdata(in: offset..<offset + count)
        offset += count
        return bytes
    }

    mutating func skip(_ count: Int) -> Bool {
        guard offset + count <= data.count else { return false }
        offset += count
        return true
    }
}

private func decodeFITValue(data: Data, baseType: UInt8, isLE: Bool) -> FITValue? {
    // Base type の下位5ビットが種別、bit7がエンディアン依存フラグ
    let kind = baseType & 0x1F
    switch kind {
    case 0x00, 0x02: // enum, uint8
        guard data.count >= 1 else { return nil }
        let v = data[0]
        return v == 0xFF ? nil : .uint8(v)
    case 0x01: // sint8
        guard data.count >= 1 else { return nil }
        let v = Int8(bitPattern: data[0])
        return v == 0x7F ? nil : .sint8(v)
    case 0x03: // sint16
        guard data.count >= 2 else { return nil }
        let raw = data.withUnsafeBytes { $0.load(as: Int16.self) }
        let v = isLE ? raw.littleEndian : raw.bigEndian
        return v == 0x7FFF ? nil : .sint16(v)
    case 0x04: // uint16
        guard data.count >= 2 else { return nil }
        let raw = data.withUnsafeBytes { $0.load(as: UInt16.self) }
        let v = isLE ? raw.littleEndian : raw.bigEndian
        return v == 0xFFFF ? nil : .uint16(v)
    case 0x05: // sint32
        guard data.count >= 4 else { return nil }
        let raw = data.withUnsafeBytes { $0.load(as: Int32.self) }
        let v = isLE ? raw.littleEndian : raw.bigEndian
        return v == 0x7FFFFFFF ? nil : .sint32(v)
    case 0x06: // uint32
        guard data.count >= 4 else { return nil }
        let raw = data.withUnsafeBytes { $0.load(as: UInt32.self) }
        let v = isLE ? raw.littleEndian : raw.bigEndian
        return v == 0xFFFFFFFF ? nil : .uint32(v)
    case 0x07: // string
        let cleaned = data.prefix { $0 != 0 }
        if let s = String(data: Data(cleaned), encoding: .utf8) {
            return .string(s)
        }
        return nil
    case 0x08: // float32
        guard data.count >= 4 else { return nil }
        let raw = data.withUnsafeBytes { $0.load(as: UInt32.self) }
        let bits = isLE ? raw.littleEndian : raw.bigEndian
        let f = Float(bitPattern: bits)
        return f.isNaN ? nil : .float32(f)
    case 0x09: // float64
        guard data.count >= 8 else { return nil }
        let raw = data.withUnsafeBytes { $0.load(as: UInt64.self) }
        let bits = isLE ? raw.littleEndian : raw.bigEndian
        let d = Double(bitPattern: bits)
        return d.isNaN ? nil : .float64(d)
    case 0x0A: // uint8z
        guard data.count >= 1 else { return nil }
        let v = data[0]
        return v == 0 ? nil : .uint8(v)
    case 0x0B: // uint16z
        guard data.count >= 2 else { return nil }
        let raw = data.withUnsafeBytes { $0.load(as: UInt16.self) }
        let v = isLE ? raw.littleEndian : raw.bigEndian
        return v == 0 ? nil : .uint16(v)
    case 0x0C: // uint32z
        guard data.count >= 4 else { return nil }
        let raw = data.withUnsafeBytes { $0.load(as: UInt32.self) }
        let v = isLE ? raw.littleEndian : raw.bigEndian
        return v == 0 ? nil : .uint32(v)
    case 0x0D: // byte
        return .bytes(data)
    case 0x0E: // sint64
        guard data.count >= 8 else { return nil }
        let raw = data.withUnsafeBytes { $0.load(as: Int64.self) }
        let v = isLE ? raw.littleEndian : raw.bigEndian
        return .sint64(v)
    case 0x0F, 0x10: // uint64 / uint64z
        guard data.count >= 8 else { return nil }
        let raw = data.withUnsafeBytes { $0.load(as: UInt64.self) }
        let v = isLE ? raw.littleEndian : raw.bigEndian
        if kind == 0x10 && v == 0 { return nil }
        return .uint64(v)
    default:
        return nil
    }
}
