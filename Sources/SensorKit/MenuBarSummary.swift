import Foundation

/// Derives the compact menu-bar title and dropdown layout from raw readings.
public enum MenuBarSummary {
    public static func title(from readings: [Reading], options: TitleOptions = .all) -> String {
        var parts: [String] = []
        if options.showCPUUsage,
           let usage = readings.first(where: { $0.group == .processor && $0.label == "Usage" }) {
            parts.append("CPU \(usage.value)")
        }
        if options.showTemperature, let celsius = hottestCPUTemperature(readings) {
            parts.append(String(format: "%.0f°C", celsius))
        }
        if options.showFan, let rpm = fastestFan(readings) {
            parts.append(String(format: "%.0f rpm", rpm))
        }
        return parts.isEmpty ? "Vitals" : parts.joined(separator: " · ")
    }

    public static func hottestCPUTemperature(_ readings: [Reading]) -> Double? {
        readings
            .filter { $0.group == .temperature && $0.label.hasPrefix("CPU") }
            .compactMap(\.number)
            .max()
    }

    public static func fastestFan(_ readings: [Reading]) -> Double? {
        readings
            .filter { $0.group == .fans && !$0.label.hasSuffix("range") }
            .compactMap(\.number)
            .max()
    }

    /// Splits a group into rows shown directly and rows tucked into an overflow submenu.
    public static func split(
        _ readings: [Reading],
        in group: SensorGroup
    ) -> (primary: [Reading], overflow: [Reading]) {
        let rows = readings.filter { $0.group == group }
        return (rows.filter(\.isPrimary), rows.filter { !$0.isPrimary })
    }
}
