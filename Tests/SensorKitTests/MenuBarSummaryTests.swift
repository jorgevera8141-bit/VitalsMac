import XCTest
@testable import SensorKit

final class MenuBarSummaryTests: XCTestCase {
    private func temp(_ label: String, _ celsius: Double, primary: Bool = true) -> Reading {
        Reading(group: .temperature, label: label, value: "\(Int(celsius))°C", number: celsius, isPrimary: primary)
    }

    private func fan(_ label: String, _ rpm: Double) -> Reading {
        Reading(group: .fans, label: label, value: "\(Int(rpm)) rpm", number: rpm)
    }

    private let usage = Reading(group: .processor, label: "Usage", value: "12%")

    func testTitleShowsUsageHottestCpuTemperatureAndFastestFan() {
        let readings = [
            usage,
            temp("CPU", 93), temp("CPU proximity", 59), temp("Battery", 35),
            fan("Fan 1", 6_340), fan("Fan 1 range", 1_250), fan("Fan 2", 6_842),
        ]

        XCTAssertEqual(MenuBarSummary.title(from: readings), "CPU 12% · 93°C · 6842 rpm")
    }

    func testHottestCpuTemperatureIgnoresNonCpuSensors() {
        let readings = [temp("Battery", 99), temp("CPU die", 70), temp("CPU PECI", 80)]
        XCTAssertEqual(MenuBarSummary.hottestCPUTemperature(readings), 80)
    }

    func testFastestFanIgnoresRangeRows() {
        let readings = [fan("Fan", 2_000), fan("Fan range", 9_999)]
        XCTAssertEqual(MenuBarSummary.fastestFan(readings), 2_000)
    }

    func testTitleOmitsMissingPartsInsteadOfShowingPlaceholders() {
        XCTAssertEqual(MenuBarSummary.title(from: [usage]), "CPU 12%")
    }

    func testTitleFallsBackWhenNothingIsAvailable() {
        XCTAssertEqual(MenuBarSummary.title(from: []), "Vitals")
    }

    func testDropdownSplitsPrimaryFromOverflowSensors() {
        let readings = [temp("CPU", 90), temp("TC1C", 80, primary: false), usage]

        let split = MenuBarSummary.split(readings, in: .temperature)

        XCTAssertEqual(split.primary.map(\.label), ["CPU"])
        XCTAssertEqual(split.overflow.map(\.label), ["TC1C"])
    }

    func testPlausibleTemperatureRejectsLowOutliers() {
        XCTAssertFalse(SMCDecoder.isPlausibleTemperature(8))
        XCTAssertTrue(SMCDecoder.isPlausibleTemperature(25))
    }

    func testOnlyKnownKeysHaveFriendlyLabels() {
        XCTAssertTrue(SMCDecoder.hasFriendlyLabel(for: "TC0P"))
        XCTAssertFalse(SMCDecoder.hasFriendlyLabel(for: "TC1C"))
    }
}
