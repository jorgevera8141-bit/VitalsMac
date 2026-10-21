import Foundation

public struct ProcessUsage: Equatable, Sendable, Identifiable {
    public let pid: Int32
    public let name: String
    /// Percent of one core, so a process using two cores fully shows 200.
    public let cpuPercent: Double
    public let memoryBytes: UInt64

    public var id: Int32 { pid }

    public init(pid: Int32, name: String, cpuPercent: Double, memoryBytes: UInt64) {
        self.pid = pid
        self.name = name
        self.cpuPercent = cpuPercent
        self.memoryBytes = memoryBytes
    }
}

public enum ProcessSort: String, CaseIterable, Identifiable, Sendable {
    case cpu = "CPU"
    case memory = "Memory"

    public var id: String { rawValue }
}

/// Parses `ps -Aceo pid=,pcpu=,rss=,comm=` output (pid, %cpu, RSS in KB, command name).
public enum ProcessListParser {
    public static func parse(_ output: String) -> [ProcessUsage] {
        output.split(whereSeparator: \.isNewline).compactMap { line in
            // The name is the rest of the line, so names containing spaces stay whole.
            let parts = line.split(maxSplits: 3, omittingEmptySubsequences: true, whereSeparator: \.isWhitespace)
            guard
                parts.count == 4,
                let pid = Int32(parts[0]),
                let cpu = Double(parts[1]),
                let residentKB = UInt64(parts[2])
            else { return nil }
            return ProcessUsage(pid: pid, name: String(parts[3]), cpuPercent: cpu, memoryBytes: residentKB * 1_024)
        }
    }

    /// The `limit` biggest processes by `sort`, ties broken by name so the list does not flicker.
    public static func top(_ items: [ProcessUsage], by sort: ProcessSort, limit: Int) -> [ProcessUsage] {
        guard limit > 0 else { return [] }
        let ordered = items.sorted { lhs, rhs in
            switch sort {
            case .cpu where lhs.cpuPercent != rhs.cpuPercent: return lhs.cpuPercent > rhs.cpuPercent
            case .memory where lhs.memoryBytes != rhs.memoryBytes: return lhs.memoryBytes > rhs.memoryBytes
            default: return lhs.name < rhs.name
            }
        }
        return Array(ordered.prefix(limit))
    }
}
