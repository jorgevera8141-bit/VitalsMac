import Foundation

/// Battery state, health and electrical readings from the `AppleSmartBattery` registry entry.
public struct BatteryInfo: Equatable, Sendable {
    /// Apple reports 65535 minutes while the estimate is still being calculated.
    static let unknownTimeRemaining = 65_535
    /// Apple recommends service once capacity falls below 80% of the original.
    static let serviceThreshold = 0.8

    public let chargeFraction: Double
    public let isCharging: Bool
    public let isPluggedIn: Bool
    public let isFullyCharged: Bool
    public let cycleCount: Int?
    public let healthFraction: Double?
    public let designCapacityMAh: Int?
    public let maxCapacityMAh: Int?
    public let temperatureC: Double?
    public let voltageV: Double?
    /// Positive while charging, negative while discharging.
    public let amperageMA: Int64?
    public let timeRemainingMinutes: Int?
    public let adapterWatts: Int?

    /// Watts flowing into (positive) or out of (negative) the battery.
    public var powerWatts: Double? {
        guard let voltageV, let amperageMA else { return nil }
        return voltageV * Double(amperageMA) / 1_000
    }

    public var stateLabel: String {
        if isFullyCharged && isPluggedIn { return "Fully charged" }
        if isCharging { return "Charging" }
        if isPluggedIn { return "Plugged in, not charging" }
        return "On battery"
    }

    public static func healthDescription(for fraction: Double) -> String {
        fraction >= serviceThreshold ? "Normal" : "Consider service"
    }

    /// Returns nil when the entry has no usable capacity reading (for example on a desktop Mac).
    public static func parse(_ properties: [String: Any]) -> BatteryInfo? {
        guard
            let current = integer(properties["CurrentCapacity"]),
            let maximum = integer(properties["MaxCapacity"]),
            maximum > 0
        else { return nil }

        let design = integer(properties["DesignCapacity"])
        // MaxCapacity is a percentage on newer Macs; only trust it as mAh when it is clearly larger.
        let rawMaximum = integer(properties["AppleRawMaxCapacity"]) ?? (maximum > 100 ? maximum : nil)
        let health: Double? = {
            guard let rawMaximum, let design, design > 0 else { return nil }
            return min(max(Double(rawMaximum) / Double(design), 0), 1)
        }()

        return BatteryInfo(
            chargeFraction: min(max(Double(current) / Double(maximum), 0), 1),
            isCharging: properties["IsCharging"] as? Bool ?? false,
            isPluggedIn: properties["ExternalConnected"] as? Bool ?? false,
            isFullyCharged: properties["FullyCharged"] as? Bool ?? false,
            cycleCount: integer(properties["CycleCount"]),
            healthFraction: health,
            designCapacityMAh: design,
            maxCapacityMAh: rawMaximum,
            temperatureC: integer(properties["Temperature"]).map { Double($0) / 100 },
            voltageV: integer(properties["Voltage"]).map { Double($0) / 1_000 },
            amperageMA: signedAmperage(properties["Amperage"]),
            timeRemainingMinutes: integer(properties["TimeRemaining"]).flatMap {
                $0 >= 0 && $0 != unknownTimeRemaining ? $0 : nil
            },
            adapterWatts: integer((properties["AdapterDetails"] as? [String: Any])?["Watts"])
        )
    }

    private static func integer(_ value: Any?) -> Int? {
        (value as? NSNumber)?.intValue
    }

    /// A negative current is sometimes reported as a huge unsigned 64-bit number; reinterpret its bits.
    private static func signedAmperage(_ value: Any?) -> Int64? {
        (value as? NSNumber).map { Int64(bitPattern: $0.uint64Value) }
    }
}
