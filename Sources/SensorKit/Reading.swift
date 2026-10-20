import Foundation

public enum SensorGroup: String, CaseIterable, Sendable {
    case processor = "Processor"
    case temperature = "Temperature"
    case fans = "Fans"
    case memory = "Memory"
    case storage = "Storage"
    case network = "Network"
    case battery = "Battery"
    case system = "System"
}

public struct Reading: Identifiable, Equatable, Sendable {
    public let id: String
    public let group: SensorGroup
    public let label: String
    public let value: String
    /// Raw numeric value (°C, rpm) when the sensor has one.
    public let number: Double?
    /// Primary rows appear directly in the dropdown; the rest go in an overflow submenu.
    public let isPrimary: Bool

    public init(group: SensorGroup, label: String, value: String, number: Double? = nil, isPrimary: Bool = true) {
        self.id = "\(group.rawValue).\(label)"
        self.group = group
        self.label = label
        self.value = value
        self.number = number
        self.isPrimary = isPrimary
    }
}

public enum Format {
    public static func bytes(_ value: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .binary)
    }

    public static func rate(bytesPerSecond: Double) -> String {
        "\(bytes(UInt64(max(0, bytesPerSecond))))/s"
    }

    public static func percent(_ fraction: Double) -> String {
        String(format: "%.0f%%", min(max(fraction, 0), 1) * 100)
    }

    public static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        if days > 0 { return "\(days)d \(hours)h \(minutes)m" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}
