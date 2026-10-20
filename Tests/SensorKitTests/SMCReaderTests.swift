import XCTest
@testable import SensorKit

/// Live smoke test against this machine's SMC. Skips where no SMC is reachable.
final class SMCReaderTests: XCTestCase {
    func testLiveReadingsAreWellFormed() throws {
        let reader = SMCReader()
        try XCTSkipUnless(reader.isAvailable, "AppleSMC not reachable on this machine")

        let readings = reader.readings()
        print("SMC readings (\(readings.count)):")
        readings.forEach { print("  [\($0.group.rawValue)] \($0.label): \($0.value)") }

        XCTAssertTrue(readings.allSatisfy { $0.group == .temperature || $0.group == .fans })
        XCTAssertTrue(readings.allSatisfy { !$0.value.isEmpty })
    }
}
