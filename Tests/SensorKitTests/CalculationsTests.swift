import XCTest
@testable import SensorKit

final class CalculationsTests: XCTestCase {
    func testCpuUsageIsBusyShareOfElapsedTicks() {
        let previous = CPUTicks(user: 100, system: 50, idle: 850, nice: 0)
        let current = CPUTicks(user: 200, system: 100, idle: 1_700, nice: 0)

        let usage = Calculations.cpuUsage(previous: previous, current: current)

        // busy delta 150, total delta 1000
        XCTAssertEqual(usage, 0.15, accuracy: 0.0001)
    }

    func testCpuUsageIsZeroWhenNoTicksElapsed() {
        let ticks = CPUTicks(user: 1, system: 1, idle: 1, nice: 1)
        XCTAssertEqual(Calculations.cpuUsage(previous: ticks, current: ticks), 0)
    }

    func testNetworkRateDividesByInterval() {
        let previous = NetworkCounters(received: 1_000, sent: 500)
        let current = NetworkCounters(received: 3_000, sent: 1_500)

        let rate = Calculations.networkRate(previous: previous, current: current, interval: 2)

        XCTAssertEqual(rate.down, 1_000)
        XCTAssertEqual(rate.up, 500)
    }

    func testNetworkRateTreatsCounterResetAsNoTraffic() {
        let previous = NetworkCounters(received: 9_000, sent: 9_000)
        let current = NetworkCounters(received: 100, sent: 100)

        let rate = Calculations.networkRate(previous: previous, current: current, interval: 1)

        XCTAssertEqual(rate.down, 0)
        XCTAssertEqual(rate.up, 0)
    }

    func testNetworkRateIsZeroForNonPositiveInterval() {
        let counters = NetworkCounters(received: 10, sent: 10)
        let rate = Calculations.networkRate(previous: counters, current: counters, interval: 0)
        XCTAssertEqual(rate.down, 0)
    }

    func testPercentClampsToValidRange() {
        XCTAssertEqual(Format.percent(1.7), "100%")
        XCTAssertEqual(Format.percent(-0.2), "0%")
        XCTAssertEqual(Format.percent(0.426), "43%")
    }

    func testDurationFormatsLargestUnits() {
        XCTAssertEqual(Format.duration(90_061), "1d 1h 1m")
        XCTAssertEqual(Format.duration(3_900), "1h 5m")
        XCTAssertEqual(Format.duration(120), "2m")
    }
}
