import XCTest
@testable import SensorKit

final class SettingsTests: XCTestCase {
    private func makeStore() -> (SettingsStore, UserDefaults, String) {
        let suite = "VitalsMacTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return (SettingsStore(defaults: defaults), defaults, suite)
    }

    func testDefaultsMatchShippedBehavior() {
        let settings = AppSettings()
        XCTAssertTrue(settings.alertsEnabled)
        XCTAssertEqual(settings.alertThreshold, 90)
        XCTAssertEqual(settings.alertSustainSeconds, 30)
        XCTAssertEqual(settings.alertCooldownMinutes, 10)
        XCTAssertTrue(settings.showCPUUsage && settings.showTemperature && settings.showFan)
    }

    func testNormalizedClampsOutOfRangeValues() {
        var settings = AppSettings()
        settings.alertThreshold = 500
        settings.alertSustainSeconds = 0
        settings.alertCooldownMinutes = 9_999

        let normalized = settings.normalized()

        XCTAssertEqual(normalized.alertThreshold, AppSettings.thresholdRange.upperBound)
        XCTAssertEqual(normalized.alertSustainSeconds, AppSettings.sustainRange.lowerBound)
        XCTAssertEqual(normalized.alertCooldownMinutes, AppSettings.cooldownRange.upperBound)
    }

    func testNormalizedTreatsNonFiniteAsDefault() {
        var settings = AppSettings()
        settings.alertThreshold = .nan
        XCTAssertEqual(settings.normalized().alertThreshold, 90)
    }

    func testPolicyUsesConfiguredValuesWithFiveDegreeHysteresis() {
        var settings = AppSettings()
        settings.alertThreshold = 80
        settings.alertSustainSeconds = 45
        settings.alertCooldownMinutes = 2

        let policy = settings.makePolicy()

        XCTAssertEqual(policy.threshold, 80)
        XCTAssertEqual(policy.rearmBelow, 75)
        XCTAssertEqual(policy.sustain, 45)
        XCTAssertEqual(policy.cooldown, 120)
    }

    func testTitleOptionsHideDisabledParts() {
        let readings = [
            Reading(group: .processor, label: "Usage", value: "12%"),
            Reading(group: .temperature, label: "CPU", value: "93°C", number: 93),
            Reading(group: .fans, label: "Fan", value: "6000 rpm", number: 6_000),
        ]
        var settings = AppSettings()
        settings.showTemperature = false

        XCTAssertEqual(MenuBarSummary.title(from: readings, options: settings.titleOptions), "CPU 12% · 6000 rpm")
    }

    func testTitleFallsBackWhenEverythingIsHidden() {
        let readings = [Reading(group: .processor, label: "Usage", value: "12%")]
        var settings = AppSettings()
        settings.showCPUUsage = false
        settings.showTemperature = false
        settings.showFan = false

        XCTAssertEqual(MenuBarSummary.title(from: readings, options: settings.titleOptions), "Vitals")
    }

    func testStoreRoundTripsSettings() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        var settings = AppSettings()
        settings.alertThreshold = 85
        settings.showFan = false

        store.save(settings)

        XCTAssertEqual(store.load(), settings)
    }

    func testStoreReturnsDefaultsWhenNothingSaved() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertEqual(store.load(), AppSettings())
    }

    func testStoreReturnsDefaultsWhenSavedDataIsCorrupt() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data("not json".utf8), forKey: SettingsStore.key)

        XCTAssertEqual(store.load(), AppSettings())
    }

    func testStoreKeepsDefaultsForFieldsMissingFromOlderSavedData() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data(#"{"alertThreshold": 82}"#.utf8), forKey: SettingsStore.key)

        let loaded = store.load()

        XCTAssertEqual(loaded.alertThreshold, 82)
        XCTAssertTrue(loaded.showFan)
        XCTAssertEqual(loaded.alertSustainSeconds, 30)
    }

    func testStoreNormalizesLoadedValues() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data(#"{"alertThreshold": 9999}"#.utf8), forKey: SettingsStore.key)

        XCTAssertEqual(store.load().alertThreshold, AppSettings.thresholdRange.upperBound)
    }
}
