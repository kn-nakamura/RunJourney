import Testing
import Foundation
@testable import RunJourney

/// `AdvancedAnalytics` の純粋関数群を検証する。
struct AdvancedAnalyticsTests {

    // MARK: - rollingKmPace

    @Test func rollingKmPace_emptyOrTooFew() {
        #expect(AdvancedAnalytics.rollingKmPace([]).isEmpty)
        #expect(AdvancedAnalytics.rollingKmPace([
            TrackPoint(timeSec: 0, distanceM: 0, lat: 0, lng: 0)
        ]).isEmpty)
    }

    @Test func rollingKmPace_uniformPace() {
        // 5:00/km 固定で 3km 走った場合: 1km/2km/3km の各ポイントで 300 sec/km
        let points: [TrackPoint] = (0...30).map { i in
            TrackPoint(
                timeSec: Double(i) * 30,           // 30 秒刻み
                distanceM: Double(i) * 100,        // 100m 刻み = 3km @ 5:00/km
                lat: 0, lng: 0
            )
        }
        let out = AdvancedAnalytics.rollingKmPace(points)
        #expect(out.count == 3)
        for p in out {
            #expect(abs(p.paceSecPerKm - 300) < 1)
        }
    }

    // MARK: - halfSplit

    @Test func halfSplit_negativeSplit() {
        // 後半が前半より速い (= second < first → negative split)
        let points: [TrackPoint] = [
            TrackPoint(timeSec: 0, distanceM: 0, lat: 0, lng: 0),
            TrackPoint(timeSec: 600, distanceM: 1500, lat: 0, lng: 0),  // half (3km の中点 1.5km)
            TrackPoint(timeSec: 1100, distanceM: 3000, lat: 0, lng: 0)  // 後半 500 秒
        ]
        let split = AdvancedAnalytics.halfSplit(points)
        #expect(split != nil)
        #expect(split!.firstHalfSec == 600)
        #expect(split!.secondHalfSec == 500)
    }

    @Test func halfSplit_emptyReturnsNil() {
        #expect(AdvancedAnalytics.halfSplit([]) == nil)
    }

    // MARK: - hrZoneDistribution

    @Test func hrZoneDistribution_zonesCorrectly() {
        // maxHR = 200。Z1 = 100..120 未満、Z3 = 140..160 未満
        let points: [TrackPoint] = [
            TrackPoint(timeSec: 0, distanceM: 0, lat: 0, lng: 0, heartRate: 110),
            TrackPoint(timeSec: 60, distanceM: 100, lat: 0, lng: 0, heartRate: 110),  // 60s in Z1
            TrackPoint(timeSec: 120, distanceM: 200, lat: 0, lng: 0, heartRate: 150)  // 60s in Z3 (110→150 を Z3 に算入)
        ]
        let dist = AdvancedAnalytics.hrZoneDistribution(points, maxHR: 200)
        #expect(dist[.z1] == 60)
        #expect(dist[.z3] == 60)
    }

    @Test func hrZoneDistribution_zeroMaxHRReturnsEmpty() {
        let points: [TrackPoint] = [
            TrackPoint(timeSec: 0, distanceM: 0, lat: 0, lng: 0, heartRate: 150),
            TrackPoint(timeSec: 60, distanceM: 100, lat: 0, lng: 0, heartRate: 150)
        ]
        #expect(AdvancedAnalytics.hrZoneDistribution(points, maxHR: 0).isEmpty)
    }

    // MARK: - planLapDeltas

    @Test func planLapDeltas_basicCumulative() {
        // target 300 sec/km, ラップ毎に距離 1km、actual: 290, 310, 305
        let laps: [LapData] = [
            LapData(lapIndex: 1, distanceM: 1000, timeSec: 290, paceSecPerKm: 290),
            LapData(lapIndex: 2, distanceM: 1000, timeSec: 310, paceSecPerKm: 310),
            LapData(lapIndex: 3, distanceM: 1000, timeSec: 305, paceSecPerKm: 305),
        ]
        let deltas = AdvancedAnalytics.planLapDeltas(actual: laps, targetSecPerKm: 300)
        #expect(deltas.count == 3)
        #expect(deltas[0].deltaSec == -10)
        #expect(deltas[1].deltaSec == 10)
        #expect(deltas[2].deltaSec == 5)
        #expect(deltas[0].cumulativeSec == -10)
        #expect(deltas[1].cumulativeSec == 0)
        #expect(deltas[2].cumulativeSec == 5)
    }

    @Test func planLapDeltas_zeroTargetReturnsEmpty() {
        let laps: [LapData] = [
            LapData(lapIndex: 1, distanceM: 1000, timeSec: 300, paceSecPerKm: 300)
        ]
        #expect(AdvancedAnalytics.planLapDeltas(actual: laps, targetSecPerKm: 0).isEmpty)
    }

    // MARK: - paceHistogram

    @Test func paceHistogram_buckets15s() {
        // 295, 305, 312, 295 → buckets (bucketSec=15): 285, 300, 300, 285
        let r1 = makeResult(avgPace: 295)
        let r2 = makeResult(avgPace: 305)
        let r3 = makeResult(avgPace: 312)
        let r4 = makeResult(avgPace: 295)
        let buckets = AdvancedAnalytics.paceHistogram([r1, r2, r3, r4], bucketSec: 15)
        // 285 バケット: 295,295 (= 2件)、300 バケット: 305,312 (= 2件)
        let dict = Dictionary(uniqueKeysWithValues: buckets.map { ($0.bucketStart, $0.count) })
        #expect(dict[285] == 2)
        #expect(dict[300] == 2)
    }

    // MARK: - longestRacingStreak

    @Test func longestRacingStreak_consecutiveYears() {
        let r1 = makeResult(year: 2018)
        let r2 = makeResult(year: 2019)
        let r3 = makeResult(year: 2020)
        let r4 = makeResult(year: 2022)
        let r5 = makeResult(year: 2023)
        // 2018-2020 (3 年連続) > 2022-2023 (2 年)
        #expect(AdvancedAnalytics.longestRacingStreak([r1, r2, r3, r4, r5]) == 3)
    }

    @Test func longestRacingStreak_emptyZero() {
        #expect(AdvancedAnalytics.longestRacingStreak([]) == 0)
    }

    // MARK: - Helpers

    private func makeResult(avgPace: Double? = nil, year: Int = 2024) -> RaceResult {
        let r = RaceResult(id: UUID(), race: nil, raceDate: dateFor(year: year), finishTimeSec: 14_400)
        if let p = avgPace {
            r.summary = SummaryStats(avgPaceSecPerKm: p, totalDistanceM: 42_195, totalTimeSec: 14_400)
        }
        return r
    }

    private func dateFor(year: Int) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = 6
        comps.day = 1
        return Calendar(identifier: .gregorian).date(from: comps) ?? .now
    }
}
