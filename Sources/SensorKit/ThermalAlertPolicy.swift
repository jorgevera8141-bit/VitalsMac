import Foundation

/// Decides when a sustained-heat notification should fire. Value type: each
/// evaluation returns the next policy state rather than mutating in place.
public struct ThermalAlertPolicy: Equatable, Sendable {
    public let threshold: Double
    public let rearmBelow: Double
    public let sustain: TimeInterval
    public let cooldown: TimeInterval

    private let aboveSince: Date?
    private let isArmed: Bool
    private let lastFired: Date?

    public init(
        threshold: Double = 90,
        rearmBelow: Double = 85,
        sustain: TimeInterval = 30,
        cooldown: TimeInterval = 600
    ) {
        self.init(
            threshold: threshold, rearmBelow: rearmBelow, sustain: sustain, cooldown: cooldown,
            aboveSince: nil, isArmed: true, lastFired: nil
        )
    }

    private init(
        threshold: Double, rearmBelow: Double, sustain: TimeInterval, cooldown: TimeInterval,
        aboveSince: Date?, isArmed: Bool, lastFired: Date?
    ) {
        self.threshold = threshold
        self.rearmBelow = rearmBelow
        self.sustain = sustain
        self.cooldown = cooldown
        self.aboveSince = aboveSince
        self.isArmed = isArmed
        self.lastFired = lastFired
    }

    /// - Parameter celsius: hottest CPU temperature, or nil when no reading is available.
    public func evaluating(celsius: Double?, at now: Date) -> (policy: ThermalAlertPolicy, shouldAlert: Bool) {
        guard let celsius else {
            return (with(aboveSince: nil), false)
        }
        if celsius < rearmBelow {
            return (with(aboveSince: nil, isArmed: true), false)
        }
        guard celsius >= threshold else {
            // Inside the hysteresis band: heat is not sustained, but we stay disarmed if we already alerted.
            return (with(aboveSince: nil), false)
        }

        let since = aboveSince ?? now
        let sustained = now.timeIntervalSince(since) >= sustain
        let cooledDown = lastFired.map { now.timeIntervalSince($0) >= cooldown } ?? true
        if isArmed && sustained && cooledDown {
            return (with(aboveSince: since, isArmed: false, lastFired: now), true)
        }
        return (with(aboveSince: since), false)
    }

    private func with(aboveSince: Date?, isArmed: Bool? = nil, lastFired: Date?? = nil) -> ThermalAlertPolicy {
        ThermalAlertPolicy(
            threshold: threshold, rearmBelow: rearmBelow, sustain: sustain, cooldown: cooldown,
            aboveSince: aboveSince,
            isArmed: isArmed ?? self.isArmed,
            lastFired: lastFired ?? self.lastFired
        )
    }
}
