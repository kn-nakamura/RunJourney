//
//  RunJourneyTests.swift
//  RunJourneyTests
//
//  Created by Kenta Nakamura on 2026/05/01.
//

import Testing
@testable import RunJourney

struct RunJourneyTests {

    // MARK: - PlaybackMath: angle <-> MapKit pitch / heading flip

    @Test func angleToMapPitch_endpointsAndMidpoint() {
        // 0° = 後方地面 → MapKit pitch 85 にクランプ (理論値は 90 だが iOS の最大が 85)
        #expect(PlaybackMath.angleToMapPitch(0) == 85)
        // 90° = 真上俯瞰 → MapKit pitch 0
        #expect(PlaybackMath.angleToMapPitch(90) == 0)
        // 180° = 前方地面 → MapKit pitch 85
        #expect(PlaybackMath.angleToMapPitch(180) == 85)
        // 中間値: 45° → pitch 45
        #expect(PlaybackMath.angleToMapPitch(45) == 45)
        // 中間値: 135° → pitch 45 (180-135)
        #expect(PlaybackMath.angleToMapPitch(135) == 45)
    }

    @Test func angleToMapPitch_clampsOutOfRange() {
        // 範囲外は丸める
        #expect(PlaybackMath.angleToMapPitch(-10) == 85)
        #expect(PlaybackMath.angleToMapPitch(200) == 85)
    }

    @Test func headingFlip_belowAndAboveDeadzone() {
        // 0..88 は反転なし
        #expect(PlaybackMath.headingFlip(forAngle: 0) == 0)
        #expect(PlaybackMath.headingFlip(forAngle: 87) == 0)
        // 88..92 のデッドゾーン: 反転なし (top-down 付近で heading 急変を起こさない)
        #expect(PlaybackMath.headingFlip(forAngle: 89) == 0)
        #expect(PlaybackMath.headingFlip(forAngle: 90) == 0)
        #expect(PlaybackMath.headingFlip(forAngle: 92) == 0)
        // 92 超で 180° 反転
        #expect(PlaybackMath.headingFlip(forAngle: 93) == 180)
        #expect(PlaybackMath.headingFlip(forAngle: 180) == 180)
    }

    // MARK: - ElevationEmphasis

    @Test func elevationEmphasis_shiftsAngleAndDistance() {
        let base = PlaybackMath.followCameraProfile(distanceKm: 42.195, emphasis: .off)
        let high = PlaybackMath.followCameraProfile(distanceKm: 42.195, emphasis: .high)
        // High emphasis lowers angle (more horizontal) and reduces distance.
        #expect(high.angle < base.angle)
        #expect(high.distance < base.distance)
        // High delta of -15° but clamped to >=30, and distance ×0.55.
        #expect(high.angle == max(30, base.angle - 15))
    }

    @Test func elevationEmphasis_offIsIdentity() {
        let a = PlaybackMath.followCameraProfile(distanceKm: 21.0975, emphasis: .off)
        let b = PlaybackMath.followCameraProfile(distanceKm: 21.0975)
        #expect(a == b)
    }
}
