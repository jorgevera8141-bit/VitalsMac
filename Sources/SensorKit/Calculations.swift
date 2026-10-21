import Foundation

/// Cumulative CPU ticks as reported by the kernel.
public struct CPUTicks: Equatable, Sendable {
    public let user: UInt64
    public let system: UInt64
    public let idle: UInt64
    public let nice: UInt64

    public init(user: UInt64, system: UInt64, idle: UInt64, nice: UInt64) {
        self.user = user
        self.system = system
        self.idle = idle
        self.nice = nice
    }

    var busy: UInt64 { user + system + nice }
    var total: UInt64 { busy + idle }
}

/// Cumulative interface byte counters.
public struct NetworkCounters: Equatable, Sendable {
    public let received: UInt64
    public let sent: UInt64

    public init(received: UInt64, sent: UInt64) {
        self.received = received
        self.sent = sent
    }
}

public enum Calculations {
    /// Fraction (0...1) of CPU time spent busy between two samples.
    public static func cpuUsage(previous: CPUTicks, current: CPUTicks) -> Double {
        guard current.total > previous.total else { return 0 }
        let busy = Double(current.busy &- previous.busy)
        let total = Double(current.total &- previous.total)
        return min(max(busy / total, 0), 1)
    }

    /// Shares (0...1) of elapsed CPU time spent in user code (including nice) and in the kernel.
    public static func cpuBreakdown(previous: CPUTicks, current: CPUTicks) -> (user: Double, system: Double) {
        guard current.total > previous.total else { return (0, 0) }
        let total = Double(current.total &- previous.total)
        let user = Double((current.user &- previous.user) &+ (current.nice &- previous.nice)) / total
        let system = Double(current.system &- previous.system) / total
        return (min(max(user, 0), 1), min(max(system, 0), 1))
    }

    /// Busy share (0...1) of each core between two samples. Empty if the core counts differ.
    public static func perCoreUsage(previous: [CPUTicks], current: [CPUTicks]) -> [Double] {
        guard previous.count == current.count else { return [] }
        return zip(previous, current).map { cpuUsage(previous: $0, current: $1) }
    }

    /// Bytes per second received and sent between two samples.
    public static func networkRate(
        previous: NetworkCounters,
        current: NetworkCounters,
        interval: TimeInterval
    ) -> (down: Double, up: Double) {
        guard interval > 0 else { return (0, 0) }
        // Counters can reset (interface restart); treat a decrease as no traffic.
        let down = current.received >= previous.received ? current.received - previous.received : 0
        let up = current.sent >= previous.sent ? current.sent - previous.sent : 0
        return (Double(down) / interval, Double(up) / interval)
    }
}
