import XCTest
@testable import SensorKit

final class DashboardLogicTests: XCTestCase {
    // MARK: SeriesHistory

    func testHistoryAppendsInOrder() {
        let history = SeriesHistory(capacity: 5).appending(1).appending(2).appending(3)
        XCTAssertEqual(history.values, [1, 2, 3])
    }

    func testHistoryDropsOldestBeyondCapacity() {
        let history = (1...5).reduce(SeriesHistory(capacity: 3)) { $0.appending(Double($1)) }
        XCTAssertEqual(history.values, [3, 4, 5])
    }

    func testHistoryAppendDoesNotMutateOriginal() {
        let original = SeriesHistory(capacity: 3).appending(1)
        _ = original.appending(2)
        XCTAssertEqual(original.values, [1])
    }

    func testHistoryCapacityIsAtLeastOne() {
        let history = SeriesHistory(capacity: 0).appending(1).appending(2)
        XCTAssertEqual(history.values, [2])
    }

    func testHistoryPeakIsLargestValue() {
        XCTAssertEqual(SeriesHistory(capacity: 5).appending(2).appending(9).appending(4).peak, 9)
        XCTAssertEqual(SeriesHistory(capacity: 5).peak, 0)
    }

    // MARK: CPU breakdown

    func testCpuBreakdownSplitsUserAndSystemShare() {
        let previous = CPUTicks(user: 100, system: 50, idle: 850, nice: 0)
        let current = CPUTicks(user: 200, system: 100, idle: 1_700, nice: 0)

        let split = Calculations.cpuBreakdown(previous: previous, current: current)

        XCTAssertEqual(split.user, 0.10, accuracy: 0.0001)
        XCTAssertEqual(split.system, 0.05, accuracy: 0.0001)
    }

    func testCpuBreakdownCountsNiceAsUser() {
        let previous = CPUTicks(user: 0, system: 0, idle: 0, nice: 0)
        let current = CPUTicks(user: 10, system: 0, idle: 80, nice: 10)

        XCTAssertEqual(Calculations.cpuBreakdown(previous: previous, current: current).user, 0.20, accuracy: 0.0001)
    }

    func testCpuBreakdownIsZeroWhenNoTicksElapsed() {
        let ticks = CPUTicks(user: 1, system: 1, idle: 1, nice: 1)
        let split = Calculations.cpuBreakdown(previous: ticks, current: ticks)
        XCTAssertEqual(split.user, 0)
        XCTAssertEqual(split.system, 0)
    }

    // MARK: HealthScore

    private func inputs(temp: Double? = 50, memory: Double = 0.5, disk: Double = 0.5) -> HealthInputs {
        HealthInputs(cpuTemperature: temp, memoryUsedFraction: memory, diskUsedFraction: disk)
    }

    func testThermalScoreFallsLinearlyBetweenCoolAndCritical() {
        XCTAssertEqual(HealthScore.compute(inputs(temp: 60)).thermals, 100)
        XCTAssertEqual(HealthScore.compute(inputs(temp: 70)).thermals, 100)
        XCTAssertEqual(HealthScore.compute(inputs(temp: 85)).thermals, 50)
        XCTAssertEqual(HealthScore.compute(inputs(temp: 100)).thermals, 0)
        XCTAssertEqual(HealthScore.compute(inputs(temp: 120)).thermals, 0)
    }

    func testMemoryAndDiskScoresPenalizeHighUsage() {
        XCTAssertEqual(HealthScore.compute(inputs(memory: 0.5)).memory, 100)
        XCTAssertEqual(HealthScore.compute(inputs(memory: 0.99)).memory, 0)
        XCTAssertEqual(HealthScore.compute(inputs(disk: 0.5)).disk, 100)
        XCTAssertEqual(HealthScore.compute(inputs(disk: 0.99)).disk, 0)
    }

    func testOverallIsAverageOfAvailableComponents() {
        let score = HealthScore.compute(inputs(temp: 50, memory: 0.5, disk: 0.5))
        XCTAssertEqual(score.overall, 100)
        XCTAssertEqual(score.label, "Excellent")
    }

    func testMissingTemperatureIsLeftOutOfTheAverage() {
        // memory 0.865 -> 50, disk 0.5 -> 100, no thermals: (50 + 100) / 2 = 75
        let score = HealthScore.compute(inputs(temp: nil, memory: 0.865, disk: 0.5))
        XCTAssertNil(score.thermals)
        XCTAssertEqual(score.overall, 75)
        XCTAssertEqual(score.label, "Good")
    }

    func testLabelsFollowOverallBands() {
        XCTAssertEqual(HealthScore.label(forOverall: 90), "Excellent")
        XCTAssertEqual(HealthScore.label(forOverall: 75), "Good")
        XCTAssertEqual(HealthScore.label(forOverall: 55), "Fair")
        XCTAssertEqual(HealthScore.label(forOverall: 20), "Needs attention")
    }

    func testMessageNamesTheWorstComponentWhenScoreIsLow() {
        let score = HealthScore.compute(inputs(temp: 105, memory: 0.5, disk: 0.5))
        XCTAssertTrue(score.message.contains("Thermals"), score.message)
    }

    func testMessageIsReassuringWhenEverythingIsHealthy() {
        let score = HealthScore.compute(inputs())
        XCTAssertFalse(score.message.contains("Thermals"))
        XCTAssertTrue(score.message.lowercased().contains("healthy"), score.message)
    }

    // MARK: Metrics

    func testMetricsFractionsAreUsedOverTotal() {
        var metrics = Metrics()
        metrics.memoryUsed = 8
        metrics.memoryTotal = 16
        metrics.diskUsed = 1
        metrics.diskTotal = 4

        XCTAssertEqual(metrics.memoryFraction, 0.5)
        XCTAssertEqual(metrics.diskFraction, 0.25)
    }

    func testMetricsFractionsAreZeroWhenTotalIsUnknown() {
        let metrics = Metrics()
        XCTAssertEqual(metrics.memoryFraction, 0)
        XCTAssertEqual(metrics.diskFraction, 0)
    }

    func testMetricsCpuTotalIsClampedToOne() {
        var metrics = Metrics()
        metrics.cpuUser = 0.7
        metrics.cpuSystem = 0.6
        XCTAssertEqual(metrics.cpuTotal, 1)
    }

    func testMetricsBuildHealthInputsFromReadings() {
        var metrics = Metrics()
        metrics.memoryUsed = 12
        metrics.memoryTotal = 16
        metrics.diskUsed = 1
        metrics.diskTotal = 2
        metrics.hottestCPU = 88

        XCTAssertEqual(
            metrics.healthInputs,
            HealthInputs(cpuTemperature: 88, memoryUsedFraction: 0.75, diskUsedFraction: 0.5)
        )
    }
}
