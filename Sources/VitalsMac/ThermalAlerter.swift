import Foundation
import SensorKit
@preconcurrency import UserNotifications

/// Feeds each sample to the alert policy and delivers a notification when it fires.
@MainActor
final class ThermalAlerter {
    private var policy = AppSettings().makePolicy()

    func update(with readings: [Reading], settings: AppSettings, at now: Date = Date()) {
        let desired = settings.makePolicy()
        if !Self.sameConfiguration(desired, policy) {
            // Changed thresholds start from a clean slate rather than inheriting old timers.
            policy = desired
        }
        guard settings.alertsEnabled else {
            policy = desired
            return
        }

        let celsius = MenuBarSummary.hottestCPUTemperature(readings)
        let result = policy.evaluating(celsius: celsius, at: now)
        policy = result.policy
        guard result.shouldAlert, let celsius else { return }

        let rpm = MenuBarSummary.fastestFan(readings)
        var body = String(format: "CPU has stayed at %.0f°C.", celsius)
        if let rpm { body += String(format: " Fans at %.0f rpm.", rpm) }
        body += " Check for heavy processes or blocked vents."
        Self.send(title: "Mac is running hot", body: body)
    }

    private static func sameConfiguration(_ a: ThermalAlertPolicy, _ b: ThermalAlertPolicy) -> Bool {
        a.threshold == b.threshold && a.rearmBelow == b.rearmBelow
            && a.sustain == b.sustain && a.cooldown == b.cooldown
    }

    private static func send(title: String, body: String) {
        // UserNotifications needs an app bundle; a bare `swift run` binary has none.
        if Bundle.main.bundleIdentifier != nil {
            sendViaNotificationCenter(title: title, body: body)
        } else {
            sendViaAppleScript(title: title, body: body)
        }
    }

    private static func sendViaNotificationCenter(title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error { NSLog("Vitals: notification authorization failed: \(error)") }
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            center.add(request) { error in
                if let error { NSLog("Vitals: could not deliver notification: \(error)") }
            }
        }
    }

    private static func sendViaAppleScript(title: String, body: String) {
        // Pass text as arguments so it is never interpolated into the script source.
        let script = "on run argv\ndisplay notification (item 2 of argv) with title (item 1 of argv)\nend run"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script, title, body]
        do {
            try process.run()
        } catch {
            NSLog("Vitals: could not run osascript for notification: \(error)")
        }
    }
}
