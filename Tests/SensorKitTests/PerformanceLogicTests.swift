import XCTest
@testable import SensorKit

final class PerformanceLogicTests: XCTestCase {
    // MARK: Per-core usage

    func testPerCoreUsageComputesEachCoreSeparately() {
        let previous = [
            CPUTicks(user: 100, system: 50, idle: 850, nice: 0),
            CPUTicks(user: 0, system: 0, idle: 1_000, nice: 0),
        ]
        let current = [
            CPUTicks(user: 200, system: 100, idle: 1_700, nice: 0),
            CPUTicks(user: 100, system: 0, idle: 1_900, nice: 0),
        ]

        let usage = Calculations.perCoreUsage(previous: previous, current: current)

        XCTAssertEqual(usage.count, 2)
        XCTAssertEqual(usage[0], 0.15, accuracy: 0.0001)
        XCTAssertEqual(usage[1], 0.10, accuracy: 0.0001)
    }

    func testPerCoreUsageIsEmptyWhenCoreCountsDiffer() {
        let one = [CPUTicks(user: 1, system: 1, idle: 1, nice: 0)]
        let two = one + one
        XCTAssertEqual(Calculations.perCoreUsage(previous: one, current: two), [])
    }

    func testPerCoreUsageIsEmptyForNoCores() {
        XCTAssertEqual(Calculations.perCoreUsage(previous: [], current: []), [])
    }

    // MARK: ps parsing

    private let sample = """
        1   0.0  12345 launchd
      412  35.5 204800 Google Chrome Helper
      999   1.2   1024 kernel_task
    """

    func testParsesPidCpuMemoryAndNamesWithSpaces() throws {
        let items = ProcessListParser.parse(sample)

        XCTAssertEqual(items.count, 3)
        let chrome = try XCTUnwrap(items.first { $0.pid == 412 })
        XCTAssertEqual(chrome.name, "Google Chrome Helper")
        XCTAssertEqual(chrome.cpuPercent, 35.5, accuracy: 0.0001)
        XCTAssertEqual(chrome.memoryBytes, 204_800 * 1_024)
    }

    func testSkipsBlankAndMalformedLines() {
        let output = """

        not a process line
          abc 1.0 2 name
          7 1.0 2
          8 2.0 4 ok
        """

        XCTAssertEqual(ProcessListParser.parse(output).map(\.pid), [8])
    }

    func testTopByCpuIsSortedDescendingAndLimited() {
        let items = ProcessListParser.parse(sample)

        let top = ProcessListParser.top(items, by: .cpu, limit: 2)

        XCTAssertEqual(top.map(\.pid), [412, 999])
    }

    func testTopByMemoryIsSortedDescending() {
        let items = ProcessListParser.parse(sample)

        let top = ProcessListParser.top(items, by: .memory, limit: 3)

        XCTAssertEqual(top.map(\.pid), [412, 1, 999])
    }

    func testTopBreaksTiesByNameForStableOrdering() {
        let items = [
            ProcessUsage(pid: 2, name: "b", cpuPercent: 5, memoryBytes: 1),
            ProcessUsage(pid: 1, name: "a", cpuPercent: 5, memoryBytes: 1),
        ]
        XCTAssertEqual(ProcessListParser.top(items, by: .cpu, limit: 2).map(\.name), ["a", "b"])
    }

    func testTopWithNonPositiveLimitIsEmpty() {
        XCTAssertEqual(ProcessListParser.top(ProcessListParser.parse(sample), by: .cpu, limit: 0), [])
    }
}
