import Foundation

/// Typed numeric values from one sampling pass, for charts and the health score.
public struct Metrics: Equatable, Sendable {
    public internal(set) var cpuUser = 0.0
    public internal(set) var cpuSystem = 0.0
    public internal(set) var memoryUsed: UInt64 = 0
    public internal(set) var memoryTotal: UInt64 = 0
    public internal(set) var diskUsed: UInt64 = 0
    public internal(set) var diskTotal: UInt64 = 0
    public internal(set) var gpuLoad: Double?
    public internal(set) var networkDown = 0.0
    public internal(set) var networkUp = 0.0
    public internal(set) var hottestCPU: Double?
    public internal(set) var batteryCharge: Double?

    public init() {}

    public var cpuTotal: Double { min(cpuUser + cpuSystem, 1) }

    public var memoryFraction: Double { Self.fraction(memoryUsed, of: memoryTotal) }

    public var diskFraction: Double { Self.fraction(diskUsed, of: diskTotal) }

    public var healthInputs: HealthInputs {
        HealthInputs(
            cpuTemperature: hottestCPU,
            memoryUsedFraction: memoryFraction,
            diskUsedFraction: diskFraction
        )
    }

    private static func fraction(_ part: UInt64, of total: UInt64) -> Double {
        total == 0 ? 0 : min(Double(part) / Double(total), 1)
    }
}

/// Display strings plus typed numbers from the same sampling pass.
public struct Snapshot: Sendable {
    public let readings: [Reading]
    public let metrics: Metrics

    public init(readings: [Reading], metrics: Metrics) {
        self.readings = readings
        self.metrics = metrics
    }
}
