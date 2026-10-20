import Foundation

/// Which parts of the summary appear in the menu-bar title.
public struct TitleOptions: Equatable, Sendable {
    public var showCPUUsage: Bool
    public var showTemperature: Bool
    public var showFan: Bool

    public init(showCPUUsage: Bool = true, showTemperature: Bool = true, showFan: Bool = true) {
        self.showCPUUsage = showCPUUsage
        self.showTemperature = showTemperature
        self.showFan = showFan
    }

    public static let all = TitleOptions()
}

/// User-adjustable preferences. Decoding tolerates missing fields so older saved data keeps working.
public struct AppSettings: Codable, Equatable, Sendable {
    public static let thresholdRange: ClosedRange<Double> = 60...110
    public static let sustainRange: ClosedRange<Double> = 10...300
    public static let cooldownRange: ClosedRange<Double> = 1...60
    /// Degrees below the alert threshold the CPU must cool to before alerting again.
    static let hysteresis: Double = 5

    public var alertsEnabled = true
    public var alertThreshold: Double = 90
    public var alertSustainSeconds: Double = 30
    public var alertCooldownMinutes: Double = 10
    public var showCPUUsage = true
    public var showTemperature = true
    public var showFan = true

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings()
        alertsEnabled = try container.decodeIfPresent(Bool.self, forKey: .alertsEnabled) ?? defaults.alertsEnabled
        alertThreshold = try container.decodeIfPresent(Double.self, forKey: .alertThreshold) ?? defaults.alertThreshold
        alertSustainSeconds = try container.decodeIfPresent(Double.self, forKey: .alertSustainSeconds)
            ?? defaults.alertSustainSeconds
        alertCooldownMinutes = try container.decodeIfPresent(Double.self, forKey: .alertCooldownMinutes)
            ?? defaults.alertCooldownMinutes
        showCPUUsage = try container.decodeIfPresent(Bool.self, forKey: .showCPUUsage) ?? defaults.showCPUUsage
        showTemperature = try container.decodeIfPresent(Bool.self, forKey: .showTemperature)
            ?? defaults.showTemperature
        showFan = try container.decodeIfPresent(Bool.self, forKey: .showFan) ?? defaults.showFan
    }

    public var titleOptions: TitleOptions {
        TitleOptions(showCPUUsage: showCPUUsage, showTemperature: showTemperature, showFan: showFan)
    }

    /// A copy with every numeric value forced into its valid range (non-finite values become the default).
    public func normalized() -> AppSettings {
        var copy = self
        let defaults = AppSettings()
        copy.alertThreshold = Self.clamp(alertThreshold, to: Self.thresholdRange, fallback: defaults.alertThreshold)
        copy.alertSustainSeconds = Self.clamp(
            alertSustainSeconds, to: Self.sustainRange, fallback: defaults.alertSustainSeconds
        )
        copy.alertCooldownMinutes = Self.clamp(
            alertCooldownMinutes, to: Self.cooldownRange, fallback: defaults.alertCooldownMinutes
        )
        return copy
    }

    public func makePolicy() -> ThermalAlertPolicy {
        let valid = normalized()
        return ThermalAlertPolicy(
            threshold: valid.alertThreshold,
            rearmBelow: valid.alertThreshold - Self.hysteresis,
            sustain: valid.alertSustainSeconds,
            cooldown: valid.alertCooldownMinutes * 60
        )
    }

    private static func clamp(_ value: Double, to range: ClosedRange<Double>, fallback: Double) -> Double {
        guard value.isFinite else { return fallback }
        return min(max(value, range.lowerBound), range.upperBound)
    }
}

/// Persists settings as JSON in UserDefaults. Unreadable data falls back to defaults.
public struct SettingsStore {
    public static let key = "vitals.settings"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> AppSettings {
        guard
            let data = defaults.data(forKey: Self.key),
            let decoded = try? JSONDecoder().decode(AppSettings.self, from: data)
        else { return AppSettings() }
        return decoded.normalized()
    }

    public func save(_ settings: AppSettings) {
        do {
            defaults.set(try JSONEncoder().encode(settings.normalized()), forKey: Self.key)
        } catch {
            NSLog("Vitals: could not save settings: \(error)")
        }
    }
}
