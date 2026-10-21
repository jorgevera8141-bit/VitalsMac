import XCTest
@testable import SensorKit

/// Live smoke test: two passes against the real system (the second has CPU/network deltas).
final class SamplerSmokeTests: XCTestCase {
    func testSnapshotMetricsAreSaneOnThisMachine() throws {
        let sampler = SystemSampler()
        _ = sampler.sampleSnapshot()
        Thread.sleep(forTimeInterval: 1)
        let metrics = sampler.sampleSnapshot().metrics

        print("Metrics: \(metrics)")
        print("Health: \(HealthScore.compute(metrics.healthInputs))")

        XCTAssertGreaterThan(metrics.memoryTotal, 0)
        XCTAssertGreaterThan(metrics.diskTotal, 0)
        XCTAssertTrue((0...1).contains(metrics.cpuTotal))
        XCTAssertTrue((0...1).contains(metrics.memoryFraction))
        XCTAssertTrue((0...1).contains(metrics.diskFraction))
        if let gpu = metrics.gpuLoad {
            XCTAssertTrue((0...1).contains(gpu))
        }
        XCTAssertEqual(metrics.perCoreUsage.count, ProcessInfo.processInfo.activeProcessorCount)
        XCTAssertTrue(metrics.perCoreUsage.allSatisfy { (0...1).contains($0) })
        print("Per-core: \(metrics.perCoreUsage.map { String(format: "%.0f%%", $0 * 100) })")
    }

    func testProcessListHasRealProcesses() {
        let processes = ProcessSampler.sample()
        let top = ProcessListParser.top(processes, by: .cpu, limit: 5)
        print("Processes: \(processes.count). Top by CPU:")
        top.forEach { print("  \($0.name): \($0.cpuPercent)% \(Format.bytes($0.memoryBytes))") }

        XCTAssertGreaterThan(processes.count, 10)
        XCTAssertTrue(processes.contains { $0.pid == 1 })
    }
}
