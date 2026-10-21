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
    }
}
