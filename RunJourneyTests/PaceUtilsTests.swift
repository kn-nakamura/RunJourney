import Testing
@testable import RunJourney

/// Web 版 marathon-record-app の paceUtils.ts をポートした PaceUtils のテスト。
struct PaceUtilsTests {

    @Test func goalTimeToPaceFloors() {
        // 4:00:00 / 42.195km = 341.39... → floor → 341 (5:41/km)
        #expect(PaceUtils.goalTimeToPace(goalTimeSeconds: 14_400, distanceKm: 42.195) == 341)
        // 25:00 / 5km = 300 (5:00/km)
        #expect(PaceUtils.goalTimeToPace(goalTimeSeconds: 1_500, distanceKm: 5) == 300)
        // 距離 0 はガード
        #expect(PaceUtils.goalTimeToPace(goalTimeSeconds: 1_500, distanceKm: 0) == 0)
    }

    @Test func paceToGoalTimeMultiplies() {
        // 341 * 42.195 = 14388.495 → round → 14388
        #expect(PaceUtils.paceToGoalTime(pacePerKm: 341, distanceKm: 42.195) == 14_388)
        // 300 * 5 = 1500
        #expect(PaceUtils.paceToGoalTime(pacePerKm: 300, distanceKm: 5) == 1_500)
    }

    @Test func formatTimeSimpleCases() {
        #expect(PaceUtils.formatTimeSimple(341) == "5:41")
        #expect(PaceUtils.formatTimeSimple(14_400) == "4:00:00")
        #expect(PaceUtils.formatTimeSimple(0) == "0:00")
    }

    @Test func generateLapsFullMarksGoal() {
        let cfg = PaceConstants.configs[.full]!
        let laps = PaceUtils.generateLaps(config: cfg, goalTimeSeconds: 14_400)
        // 5km 刻みで 8 ラップ + 端数 (42.195) の GOAL を含む
        #expect(laps.contains { $0.distanceLabel == "GOAL" })
        // 最後のラップは GOAL
        #expect(laps.last?.distanceLabel == "GOAL")
        // ラップ数 = 9 (5,10,15,20,25,30,35,40,42.195)
        #expect(laps.count == 9)
    }

    @Test func generateLapsHalfHasGoal() {
        let cfg = PaceConstants.configs[.half]!
        let laps = PaceUtils.generateLaps(config: cfg, goalTimeSeconds: 2 * 3600)
        #expect(laps.last?.distanceLabel == "GOAL")
    }

    @Test func formatPaceSimpleZeroPad() {
        #expect(PaceUtils.formatPaceSimple(305) == "5:05")
        #expect(PaceUtils.formatPaceSimple(0) == "0:00")
    }
}
