import XCTest
@testable import SensorKit

final class BatteryTests: XCTestCase {
    /// Shaped like the AppleSmartBattery registry entry on a laptop running on battery.
    private func properties(_ overrides: [String: Any] = [:]) -> [String: Any] {
        var base: [String: Any] = [
            "CurrentCapacity": 56,
            "MaxCapacity": 100,
            "DesignCapacity": 6_000,
            "AppleRawMaxCapacity": 5_400,
            "CycleCount": 312,
            "Temperature": 3_050,
            "Voltage": 11_400,
            "Amperage": -1_500,
            "IsCharging": false,
            "ExternalConnected": false,
            "FullyCharged": false,
            "TimeRemaining": 180,
            "AdapterDetails": ["Watts": 61],
        ]
        base.merge(overrides) { _, new in new }
        return base
    }

    private func parse(_ overrides: [String: Any] = [:]) throws -> BatteryInfo {
        try XCTUnwrap(BatteryInfo.parse(properties(overrides)))
    }

    func testParsesChargeHealthCyclesAndElectricals() throws {
        let battery = try parse()

        XCTAssertEqual(battery.chargeFraction, 0.56, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(battery.healthFraction), 0.9, accuracy: 0.0001)
        XCTAssertEqual(battery.cycleCount, 312)
        XCTAssertEqual(battery.designCapacityMAh, 6_000)
        XCTAssertEqual(battery.maxCapacityMAh, 5_400)
        XCTAssertEqual(try XCTUnwrap(battery.temperatureC), 30.5, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(battery.voltageV), 11.4, accuracy: 0.0001)
        XCTAssertEqual(battery.amperageMA, -1_500)
        XCTAssertEqual(battery.timeRemainingMinutes, 180)
        XCTAssertEqual(battery.adapterWatts, 61)
    }

    func testPowerIsNegativeWhenDischargingAndPositiveWhenCharging() throws {
        XCTAssertEqual(try XCTUnwrap(parse().powerWatts), -17.1, accuracy: 0.0001)
        XCTAssertEqual(
            try XCTUnwrap(parse(["Amperage": 2_000, "IsCharging": true]).powerWatts), 22.8, accuracy: 0.0001
        )
    }

    func testNegativeAmperageReportedAsUnsigned64BitIsDecoded() throws {
        let wrapped = NSNumber(value: UInt64(bitPattern: -1_500))
        XCTAssertEqual(try parse(["Amperage": wrapped]).amperageMA, -1_500)
    }

    func testHealthFallsBackToMaxCapacityWhenItIsInMilliampHours() throws {
        var raw = properties(["MaxCapacity": 5_100])
        raw["AppleRawMaxCapacity"] = nil

        let battery = try XCTUnwrap(BatteryInfo.parse(raw))

        XCTAssertEqual(try XCTUnwrap(battery.healthFraction), 0.85, accuracy: 0.0001)
    }

    func testHealthIsUnknownWhenOnlyAPercentageIsAvailable() throws {
        var raw = properties()
        raw["AppleRawMaxCapacity"] = nil

        XCTAssertNil(try XCTUnwrap(BatteryInfo.parse(raw)).healthFraction)
    }

    func testTimeRemainingSentinelMeansUnknown() throws {
        XCTAssertNil(try parse(["TimeRemaining": 65_535]).timeRemainingMinutes)
    }

    func testReturnsNilWithoutACapacityReading() {
        var raw = properties()
        raw["CurrentCapacity"] = nil
        XCTAssertNil(BatteryInfo.parse(raw))
    }

    func testStateLabels() throws {
        XCTAssertEqual(try parse().stateLabel, "On battery")
        XCTAssertEqual(try parse(["IsCharging": true, "ExternalConnected": true]).stateLabel, "Charging")
        XCTAssertEqual(try parse(["FullyCharged": true, "ExternalConnected": true]).stateLabel, "Fully charged")
        XCTAssertEqual(try parse(["ExternalConnected": true]).stateLabel, "Plugged in, not charging")
    }

    func testHealthDescriptionFollowsTheServiceThreshold() {
        XCTAssertEqual(BatteryInfo.healthDescription(for: 0.9), "Normal")
        XCTAssertEqual(BatteryInfo.healthDescription(for: 0.79), "Consider service")
    }
}
