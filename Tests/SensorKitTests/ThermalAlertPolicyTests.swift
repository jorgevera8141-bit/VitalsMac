import XCTest
@testable import SensorKit

final class ThermalAlertPolicyTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000_000)
    private func at(_ seconds: TimeInterval) -> Date { start.addingTimeInterval(seconds) }

    /// Feeds (seconds, celsius) samples through a policy; returns the seconds at which alerts fired.
    private func firedTimes(
        _ samples: [(TimeInterval, Double?)],
        policy: ThermalAlertPolicy = ThermalAlertPolicy(threshold: 90, rearmBelow: 85, sustain: 30, cooldown: 600)
    ) -> [TimeInterval] {
        var current = policy
        var fired: [TimeInterval] = []
        for (seconds, celsius) in samples {
            let result = current.evaluating(celsius: celsius, at: at(seconds))
            current = result.policy
            if result.shouldAlert { fired.append(seconds) }
        }
        return fired
    }

    func testNoAlertWhileBelowThreshold() {
        XCTAssertEqual(firedTimes([(0, 70), (60, 89.9), (120, 80)]), [])
    }

    func testNoAlertBeforeHeatHasBeenSustained() {
        XCTAssertEqual(firedTimes([(0, 95), (10, 95), (29, 95)]), [])
    }

    func testAlertsOnceHeatIsSustained() {
        XCTAssertEqual(firedTimes([(0, 95), (15, 96), (30, 94)]), [30])
    }

    func testDoesNotRepeatWhileStillHot() {
        let samples = (0...40).map { (TimeInterval($0 * 10), 95.0 as Double?) }
        XCTAssertEqual(firedTimes(samples), [30])
    }

    func testBriefSpikeDoesNotAlert() {
        XCTAssertEqual(firedTimes([(0, 95), (10, 70), (20, 95), (40, 95)]), [])
    }

    func testMissingReadingResetsTheSustainTimer() {
        XCTAssertEqual(firedTimes([(0, 95), (20, nil), (40, 95), (60, 95)]), [])
    }

    func testHysteresisBandDoesNotRearm() {
        // Alert at 30, dip to 87 (above rearm 85), hot again: must stay quiet.
        let samples: [(TimeInterval, Double?)] = [(0, 95), (30, 95), (700, 87), (710, 95), (800, 95)]
        XCTAssertEqual(firedTimes(samples), [30])
    }

    func testRearmsAfterCoolingAndAlertsAgainAfterCooldown() {
        let samples: [(TimeInterval, Double?)] = [
            (0, 95), (30, 95),       // first alert
            (100, 70),               // cools below rearm
            (700, 95), (730, 95),    // hot again, past cooldown
        ]
        XCTAssertEqual(firedTimes(samples), [30, 730])
    }

    func testCooldownSuppressesQuickSecondAlert() {
        let samples: [(TimeInterval, Double?)] = [
            (0, 95), (30, 95),       // first alert
            (40, 70),                // cools
            (50, 95), (80, 95),      // hot again but inside cooldown
            (640, 95),               // cooldown over, still sustained
        ]
        XCTAssertEqual(firedTimes(samples), [30, 640])
    }
}
