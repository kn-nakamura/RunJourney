import Testing
import Foundation
@testable import RunJourney

/// `AIReviewPromptBuilder.buildUserPrompt` を Apple Intelligence 非依存で検証する。
@MainActor
struct AIReviewPromptBuilderTests {

    // MARK: - Helpers

    private func makeFullResult() -> RaceResult {
        let race = Race(
            name: "Tokyo Marathon",
            category: .fullMarathon,
            distanceKm: 42.195
        )
        let result = RaceResult(
            race: race,
            raceDate: Date(timeIntervalSince1970: 1_700_000_000),
            finishTimeSec: 12_600  // 3:30:00
        )
        result.isPB = true
        result.weatherDescription = .cloudy
        result.weatherTempC = 14.5
        result.condition = .good
        result.overallPlace = 1234
        result.totalFinishers = 30000
        result.ageGroupPlace = 78
        result.comment = "Felt strong at the start, faded in the last 5km."
        result.summary = SummaryStats(
            avgPaceSecPerKm: 298.5,
            totalDistanceM: 42_195,
            totalTimeSec: 12_600,
            avgHeartRate: 162,
            maxHeartRate: 180,
            elevationGainM: 145.4,
            elevationLossM: 142.1,
            totalCalories: 2950,
            avgCadence: 178,
            avgPowerW: 280,
            avgTemperatureC: 15.0
        )
        result.lapData = (1...4).map { i in
            LapData(
                lapIndex: i,
                distanceM: 1000,
                timeSec: 295,
                paceSecPerKm: 295,
                avgHeartRate: 160 + i
            )
        }
        return result
    }

    // MARK: - Tests

    @Test func includesCoreEnglishLabelsWhenSummaryFull() {
        let result = makeFullResult()
        let prompt = AIReviewPromptBuilder.buildUserPrompt(
            result: result,
            race: result.race,
            plan: nil,
            unit: .km
        )
        #expect(prompt.contains("Race: Tokyo Marathon"))
        #expect(prompt.contains("Category: Full"))
        #expect(prompt.contains("Distance: 42.195 km"))
        #expect(prompt.contains("Finish Time: 3:30:00"))
        #expect(prompt.contains("Avg Pace:"))
        #expect(prompt.contains("Avg HR: 162 bpm"))
        #expect(prompt.contains("Max HR: 180 bpm"))
        #expect(prompt.contains("Elevation Gain: 145 m"))
        #expect(prompt.contains("Elevation Loss: 142 m"))
        #expect(prompt.contains("Avg Cadence: 178 spm"))
        #expect(prompt.contains("Avg Power: 280 W"))
        #expect(prompt.contains("Calories: 2950 kcal"))
        #expect(prompt.contains("Weather: Cloudy"))
        #expect(prompt.contains("Self-rated Condition: Good"))
        #expect(prompt.contains("Placement: 1234 / 30000"))
        #expect(prompt.contains("Age Group Place: 78"))
        #expect(prompt.contains("Personal Best: yes"))
        #expect(prompt.contains("Lap Count: 4"))
        #expect(prompt.contains("Write the reflection now."))
    }

    @Test func skipsNilFields() {
        let race = Race(name: "Local 5K", category: .fiveK, distanceKm: 5)
        let result = RaceResult(race: race, finishTimeSec: 1_500)
        // No summary, no comment, no weather, no lap data.

        let prompt = AIReviewPromptBuilder.buildUserPrompt(
            result: result,
            race: race,
            plan: nil,
            unit: .km
        )

        // Should not contain any "nil" or "—" leakage.
        #expect(!prompt.contains("nil"))
        #expect(!prompt.contains("Avg HR:"))
        #expect(!prompt.contains("Avg Pace:"))
        #expect(!prompt.contains("Weather:"))
        #expect(!prompt.contains("User Note:"))
        #expect(!prompt.contains("Splits"))
        // But the basic fields are present.
        #expect(prompt.contains("Race: Local 5K"))
        #expect(prompt.contains("Finish Time: 25:00"))
    }

    @Test func userNoteOnlyAppearsWhenCommentNonEmpty() {
        let result = makeFullResult()
        let withNote = AIReviewPromptBuilder.buildUserPrompt(
            result: result,
            race: result.race,
            plan: nil,
            unit: .km
        )
        #expect(withNote.contains("User Note: Felt strong at the start"))

        result.comment = "   "  // whitespace-only treated as empty
        let trimmed = AIReviewPromptBuilder.buildUserPrompt(
            result: result,
            race: result.race,
            plan: nil,
            unit: .km
        )
        #expect(!trimmed.contains("User Note:"))

        result.comment = nil
        let noNote = AIReviewPromptBuilder.buildUserPrompt(
            result: result,
            race: result.race,
            plan: nil,
            unit: .km
        )
        #expect(!noNote.contains("User Note:"))
    }

    @Test func planBlockOnlyAppearsWhenPlanProvided() {
        let result = makeFullResult()
        let plan = PacePlan(
            name: "Sub-3:30",
            targetDistanceKm: 42.195,
            targetTimeSec: 12_600
        )
        let withPlan = AIReviewPromptBuilder.buildUserPrompt(
            result: result,
            race: result.race,
            plan: plan,
            unit: .km
        )
        #expect(withPlan.contains("Plan: Sub-3:30"))

        let withoutPlan = AIReviewPromptBuilder.buildUserPrompt(
            result: result,
            race: result.race,
            plan: nil,
            unit: .km
        )
        #expect(!withoutPlan.contains("Plan:"))
    }

    @Test func halfSplitLineRequiresTrackPoints() {
        let result = makeFullResult()
        // No trackPoints in fixture → no half split line.
        let withoutTrack = AIReviewPromptBuilder.buildUserPrompt(
            result: result,
            race: result.race,
            plan: nil,
            unit: .km
        )
        #expect(!withoutTrack.contains("Half Split:"))

        result.trackPoints = [
            TrackPoint(timeSec: 0, distanceM: 0, lat: 0, lng: 0),
            TrackPoint(timeSec: 600, distanceM: 1500, lat: 0, lng: 0),
            TrackPoint(timeSec: 1100, distanceM: 3000, lat: 0, lng: 0)
        ]
        let withTrack = AIReviewPromptBuilder.buildUserPrompt(
            result: result,
            race: result.race,
            plan: nil,
            unit: .km
        )
        #expect(withTrack.contains("Half Split:"))
        #expect(withTrack.contains("negative split"))
    }

    @Test func longLapListIsCompressedToHeadAndTail() {
        let race = Race(name: "Marathon", category: .fullMarathon, distanceKm: 42.195)
        let result = RaceResult(race: race, finishTimeSec: 14_400)
        result.lapData = (1...10).map { i in
            LapData(lapIndex: i, distanceM: 1000, timeSec: 360, paceSecPerKm: 360)
        }
        let prompt = AIReviewPromptBuilder.buildUserPrompt(
            result: result,
            race: race,
            plan: nil,
            unit: .km
        )
        #expect(prompt.contains("Lap Count: 10"))
        #expect(prompt.contains("(4 laps omitted)"))
        // First three and last three lap indices should appear.
        #expect(prompt.contains("1. 1 km"))
        #expect(prompt.contains("10. 1 km"))
        // The middle laps should be omitted.
        #expect(!prompt.contains("5. 1 km"))
        #expect(!prompt.contains("6. 1 km"))
    }

    @Test func dnfStatusIsLabeledAndWorksWithoutFinishTime() {
        let race = Race(name: "Trail 50K", category: .trail)
        let result = RaceResult(race: race, finishTimeSec: nil)
        result.isDNF = true
        let prompt = AIReviewPromptBuilder.buildUserPrompt(
            result: result,
            race: race,
            plan: nil,
            unit: .km
        )
        #expect(prompt.contains("Status: DNF"))
        #expect(!prompt.contains("Finish Time:"))
    }

    @Test func milesUnitChangesPaceAndDistanceLabels() {
        let result = makeFullResult()
        let prompt = AIReviewPromptBuilder.buildUserPrompt(
            result: result,
            race: result.race,
            plan: nil,
            unit: .mi
        )
        #expect(prompt.contains("/mi"))
        #expect(prompt.contains("mi"))
    }
}
