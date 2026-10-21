import Foundation

/// A fixed-capacity rolling series for charts. Value type: appending returns a new series.
public struct SeriesHistory: Equatable, Sendable {
    public let capacity: Int
    public let values: [Double]

    public init(capacity: Int) {
        self.init(capacity: capacity, values: [])
    }

    private init(capacity: Int, values: [Double]) {
        self.capacity = max(1, capacity)
        self.values = values
    }

    public func appending(_ value: Double) -> SeriesHistory {
        SeriesHistory(capacity: capacity, values: Array((values + [value]).suffix(capacity)))
    }

    public var peak: Double { values.max() ?? 0 }
}

public struct HealthInputs: Equatable, Sendable {
    public let cpuTemperature: Double?
    public let memoryUsedFraction: Double
    public let diskUsedFraction: Double

    public init(cpuTemperature: Double?, memoryUsedFraction: Double, diskUsedFraction: Double) {
        self.cpuTemperature = cpuTemperature
        self.memoryUsedFraction = memoryUsedFraction
        self.diskUsedFraction = diskUsedFraction
    }
}

/// A 0...100 summary of how healthy the Mac looks, built from thermals, memory and disk.
public struct HealthScore: Equatable, Sendable {
    public let overall: Int
    public let thermals: Int?
    public let memory: Int
    public let disk: Int
    public let label: String
    public let message: String

    /// Below this component score the dashboard calls the component out by name.
    private static let attentionThreshold = 70

    public static func compute(_ inputs: HealthInputs) -> HealthScore {
        let thermals = inputs.cpuTemperature.map { score($0, good: 70, bad: 100) }
        let memory = score(inputs.memoryUsedFraction, good: 0.75, bad: 0.98)
        let disk = score(inputs.diskUsedFraction, good: 0.80, bad: 0.98)

        let components: [(name: String, value: Int)] =
            [("Thermals", thermals), ("Memory", memory), ("Disk", disk)]
                .compactMap { name, value in value.map { (name, $0) } }
        let overall = Int((Double(components.map(\.value).reduce(0, +)) / Double(components.count)).rounded())

        let message: String
        if let worst = components.min(by: { $0.value < $1.value }), worst.value < attentionThreshold {
            message = "Check \(worst.name): it is pulling your score down."
        } else {
            message = "Everything looks healthy."
        }
        return HealthScore(
            overall: overall, thermals: thermals, memory: memory, disk: disk,
            label: label(forOverall: overall), message: message
        )
    }

    public static func label(forOverall overall: Int) -> String {
        switch overall {
        case 85...: return "Excellent"
        case 70..<85: return "Good"
        case 50..<70: return "Fair"
        default: return "Needs attention"
        }
    }

    /// 100 at or below `good`, 0 at or above `bad`, linear in between.
    private static func score(_ value: Double, good: Double, bad: Double) -> Int {
        guard value.isFinite else { return 0 }
        if value <= good { return 100 }
        if value >= bad { return 0 }
        return Int((100 * (bad - value) / (bad - good)).rounded())
    }
}
