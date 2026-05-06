import Foundation
import CoreLocation
#if canImport(HealthKit)
import HealthKit
#endif

/// Apple Health (HealthKit) からランニングワークアウトを読み取り、
/// `ParsedActivity` に変換するためのヘルパ。
///
/// 設計メモ:
/// - 読み込み専用（`HKHealthStore.requestAuthorization(toShare: nil, read: ...)` のみ）
/// - 対象は `HKWorkoutActivityType.running` のみ
/// - 取得対象データ:
///   - HKWorkout 本体（startDate / endDate / totalDistance / totalEnergyBurned）
///   - HKWorkoutRoute → HKWorkoutRouteQuery で位置の時系列
///   - 心拍 → HKQuantityType heartRate (workout 期間に絞った HKSampleQuery)
/// - ラップ:
///   - HKWorkout.workoutEvents の `.lap` イベントがあればそれを使う
///   - 無ければトラックポイントから 1km ごとに自動分割（GPXParser と同じ流儀）
enum HealthKitWorkoutFetcher {

#if canImport(HealthKit)

    /// HealthKit が利用可能かどうか（シミュレータや非対応端末で false）。
    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// プロセス全体で使い回す `HKHealthStore`。HealthKit はインスタンスを増やす必要がない。
    static let store = HKHealthStore()

    enum FetchError: LocalizedError {
        case notAvailable
        case authorizationDenied
        case noRoute
        case queryFailed(String)

        var errorDescription: String? {
            switch self {
            case .notAvailable:
                return "Apple Health is not available on this device."
            case .authorizationDenied:
                return "RunJourney does not have permission to read workouts. Enable access in Settings → Health → Data Access & Devices → RunJourney."
            case .noRoute:
                return "This workout has no GPS route."
            case .queryFailed(let detail):
                return "Health query failed: \(detail)"
            }
        }
    }

    // MARK: - Authorization

    /// 必要な read 権限のまとめ。`requestAuthorization` の戻り値は「ダイアログを表示できたか」
    /// であり、ユーザーが拒否したかどうかは取れない仕様（プライバシー上）。実際の読み込みで
    /// 0 件 / アクセス拒否相当のエラーが返ったら denied として扱う。
    private static var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute(),
        ]
        if let hr = HKObjectType.quantityType(forIdentifier: .heartRate) { types.insert(hr) }
        if let dist = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) { types.insert(dist) }
        if let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { types.insert(energy) }
        return types
    }

    /// HealthKit の権限ダイアログを表示する。ユーザー操作後に呼び出し側が `recentRunningWorkouts`
    /// を実行して、空配列ならアクセス拒否扱いにするのが安全。
    static func requestAuthorization() async throws {
        guard isAvailable else { throw FetchError.notAvailable }
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    // MARK: - Workout list

    /// 指定期間のランニングワークアウトを新しい順で返す。
    /// - Parameters:
    ///   - within: 取得対象の期間。デフォルトは過去 1 年間。
    ///   - limit:  最大件数（HK 既定 = 無制限。UI 用に 50 程度に絞ると体感が軽い）
    static func recentRunningWorkouts(
        within interval: DateInterval = .init(start: Date.now.addingTimeInterval(-365 * 86_400), end: .now),
        limit: Int = 50
    ) async throws -> [HKWorkout] {
        guard isAvailable else { throw FetchError.notAvailable }

        let workoutType = HKObjectType.workoutType()
        let typePredicate = HKQuery.predicateForWorkouts(with: .running)
        let datePredicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end)
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [typePredicate, datePredicate])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: limit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: FetchError.queryFailed(error.localizedDescription))
                    return
                }
                let workouts = (samples as? [HKWorkout]) ?? []
                continuation.resume(returning: workouts)
            }
            store.execute(query)
        }
    }

    // MARK: - ParsedActivity construction

    /// 1 件の HKWorkout を `ParsedActivity` に変換する。
    /// ルートが無い workout は `FetchError.noRoute` を投げる（取り込んでも意味が無いため）。
    static func parsedActivity(from workout: HKWorkout) async throws -> ParsedActivity {
        let routeLocations = try await loadRouteLocations(for: workout)
        guard !routeLocations.isEmpty else { throw FetchError.noRoute }

        let heartRateSamples = (try? await loadHeartRate(for: workout)) ?? []
        let trackPoints = makeTrackPoints(
            from: routeLocations,
            heartRateSamples: heartRateSamples,
            workoutStart: workout.startDate
        )

        let laps = lapsFromEvents(workout: workout, trackPoints: trackPoints)
            ?? autoSplitLapsEveryKilometer(trackPoints: trackPoints)
        let summary = ActivityMath.buildSummaryStats(trackPoints: trackPoints, laps: laps)

        return ParsedActivity(
            trackPoints: trackPoints,
            laps: laps,
            summary: summary,
            startDate: workout.startDate,
            endDate: workout.endDate,
            finishTimeSec: workout.duration,
            startCoordinate: trackPoints.first.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) },
            endCoordinate: trackPoints.last.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) }
        )
    }

    // MARK: - Route locations

    /// HKWorkout に紐付く全 HKWorkoutRoute のサンプルから `CLLocation` 配列を取り出す。
    /// 1 つのワークアウトに複数 route が紐付くことがあるため flatten + 時系列ソートする。
    private static func loadRouteLocations(for workout: HKWorkout) async throws -> [CLLocation] {
        let routes = try await loadRouteSamples(for: workout)
        var locations: [CLLocation] = []
        for route in routes {
            let chunk = try await locations(for: route)
            locations.append(contentsOf: chunk)
        }
        locations.sort { $0.timestamp < $1.timestamp }
        return locations
    }

    private static func loadRouteSamples(for workout: HKWorkout) async throws -> [HKWorkoutRoute] {
        let predicate = HKQuery.predicateForObjects(from: workout)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: HKSeriesType.workoutRoute(),
                predicate: predicate,
                anchor: nil,
                limit: HKObjectQueryNoLimit
            ) { _, samples, _, _, error in
                if let error {
                    continuation.resume(throwing: FetchError.queryFailed(error.localizedDescription))
                    return
                }
                continuation.resume(returning: (samples as? [HKWorkoutRoute]) ?? [])
            }
            store.execute(query)
        }
    }

    private static func locations(for route: HKWorkoutRoute) async throws -> [CLLocation] {
        var collected: [CLLocation] = []
        return try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            let query = HKWorkoutRouteQuery(route: route) { _, locations, done, error in
                if let error {
                    if !resumed {
                        resumed = true
                        continuation.resume(throwing: FetchError.queryFailed(error.localizedDescription))
                    }
                    return
                }
                if let locations { collected.append(contentsOf: locations) }
                if done, !resumed {
                    resumed = true
                    continuation.resume(returning: collected)
                }
            }
            store.execute(query)
        }
    }

    // MARK: - Heart rate

    private struct HRSample {
        let date: Date
        let bpm: Int
    }

    /// workout 期間内の心拍サンプルを時系列で返す。
    private static func loadHeartRate(for workout: HKWorkout) async throws -> [HRSample] {
        guard let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return [] }
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        let predicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: hrType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: FetchError.queryFailed(error.localizedDescription))
                    return
                }
                let hrs: [HRSample] = (samples as? [HKQuantitySample])?.map {
                    HRSample(date: $0.startDate, bpm: Int($0.quantity.doubleValue(for: bpmUnit).rounded()))
                } ?? []
                continuation.resume(returning: hrs)
            }
            store.execute(query)
        }
    }

    // MARK: - TrackPoint assembly

    /// 位置サンプルとHRサンプルを統合してトラックポイントの配列にする。
    /// 距離は `CLLocation.distance(from:)` で隣接点ごとに加算（FIT 等と同じ方式）。
    private static func makeTrackPoints(
        from locations: [CLLocation],
        heartRateSamples: [HRSample],
        workoutStart: Date
    ) -> [TrackPoint] {
        guard !locations.isEmpty else { return [] }
        var points: [TrackPoint] = []
        points.reserveCapacity(locations.count)

        var cumDist: Double = 0
        var prev: CLLocation?
        var hrCursor = 0

        for loc in locations {
            if let p = prev {
                cumDist += loc.distance(from: p)
            }
            prev = loc

            // HR は時系列が一致しないので「直近で workout 期間内の最も近いサンプル」を引く。
            // hrCursor を進めながら線形に検索することで全体 O(n + m)。
            while hrCursor + 1 < heartRateSamples.count
                && heartRateSamples[hrCursor + 1].date <= loc.timestamp {
                hrCursor += 1
            }
            let hr: Int? = {
                guard !heartRateSamples.isEmpty else { return nil }
                let candidate = heartRateSamples[min(hrCursor, heartRateSamples.count - 1)]
                // 過度に古い HR は紐付けない（5 分超は捨てる）
                return abs(candidate.date.timeIntervalSince(loc.timestamp)) < 300 ? candidate.bpm : nil
            }()

            let speed = loc.speed >= 0 ? loc.speed : nil
            points.append(TrackPoint(
                timeSec: loc.timestamp.timeIntervalSince(workoutStart),
                distanceM: cumDist,
                lat: loc.coordinate.latitude,
                lng: loc.coordinate.longitude,
                altitudeM: loc.altitude,
                heartRate: hr,
                speedMs: speed
            ))
        }
        return points
    }

    // MARK: - Laps

    /// `HKWorkout.workoutEvents` の `.lap` を使ってラップを組み立てる。
    /// イベントが無い場合は nil を返し、呼び出し側で auto-split にフォールバックする。
    private static func lapsFromEvents(workout: HKWorkout, trackPoints: [TrackPoint]) -> [LapData]? {
        let events = (workout.workoutEvents ?? []).filter { $0.type == .lap }
        guard events.count >= 2, !trackPoints.isEmpty else { return nil }
        // .lap イベントは「区切り」を示すので、N 個あれば N-1 ラップ + 末尾ラップで N 個になる。
        // ここでは workout.startDate 〜 各イベントの dateInterval.start 〜 endDate を境界に使う。
        var boundaries: [Date] = [workout.startDate]
        for event in events {
            boundaries.append(event.dateInterval.start)
        }
        boundaries.append(workout.endDate)
        boundaries = boundaries.sorted()

        var laps: [LapData] = []
        for i in 0..<(boundaries.count - 1) {
            let start = boundaries[i]
            let end = boundaries[i + 1]
            guard end > start else { continue }
            let segment = trackPoints.filter {
                let t = workout.startDate.addingTimeInterval($0.timeSec)
                return t >= start && t <= end
            }
            guard let first = segment.first, let last = segment.last else { continue }
            let dist = max(0, last.distanceM - first.distanceM)
            let time = max(0, last.timeSec - first.timeSec)
            guard dist > 0, time > 0 else { continue }

            let validHRs = segment.compactMap { $0.heartRate }.filter { $0 > 0 }
            let altitudes = segment.compactMap { $0.altitudeM }
            var gain = 0.0, loss = 0.0
            for j in 1..<altitudes.count {
                let d = altitudes[j] - altitudes[j - 1]
                if d > 0 { gain += d } else { loss += -d }
            }

            laps.append(LapData(
                lapIndex: laps.count + 1,
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
        return laps.isEmpty ? nil : laps
    }

    /// トラックポイントから 1km ごとに区切ってラップを生成する。
    /// HKWorkout に lap イベントが無い場合のフォールバック。
    private static func autoSplitLapsEveryKilometer(trackPoints: [TrackPoint]) -> [LapData] {
        guard let last = trackPoints.last, last.distanceM > 0 else { return [] }
        var laps: [LapData] = []
        var lapStart: TrackPoint = trackPoints[0]
        var nextThresholdM = 1000.0

        for p in trackPoints.dropFirst() {
            if p.distanceM >= nextThresholdM {
                let dist = p.distanceM - lapStart.distanceM
                let time = p.timeSec - lapStart.timeSec
                if dist > 0 && time > 0 {
                    laps.append(LapData(
                        lapIndex: laps.count + 1,
                        distanceM: dist,
                        timeSec: time,
                        paceSecPerKm: time / (dist / 1000.0),
                        triggerMethod: .distance
                    ))
                }
                lapStart = p
                nextThresholdM += 1000.0
            }
        }
        // 残りの端数を最終ラップにする
        let dist = last.distanceM - lapStart.distanceM
        let time = last.timeSec - lapStart.timeSec
        if dist > 0 && time > 0 {
            laps.append(LapData(
                lapIndex: laps.count + 1,
                distanceM: dist,
                timeSec: time,
                paceSecPerKm: time / (dist / 1000.0),
                triggerMethod: .sessionEnd
            ))
        }
        return laps
    }

#else
    // 非 HealthKit プラットフォーム（macOS 13 未満等）向けスタブ。
    static var isAvailable: Bool { false }
#endif
}
