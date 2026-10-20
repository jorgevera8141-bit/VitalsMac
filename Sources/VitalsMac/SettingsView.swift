import AppKit
import SensorKit
import SwiftUI

/// Holds the live settings and saves every change.
@MainActor
final class SettingsModel: ObservableObject {
    @Published var settings: AppSettings {
        didSet { store.save(settings) }
    }

    private let store: SettingsStore

    init(store: SettingsStore = SettingsStore()) {
        self.store = store
        self.settings = store.load()
    }
}

struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    @ObservedObject var loginItem: LoginItemModel

    var body: some View {
        Form {
            Section {
                Toggle(
                    "Launch at login",
                    isOn: Binding(get: { loginItem.isEnabled }, set: { loginItem.setEnabled($0) })
                )
                .disabled(!loginItem.isAvailable)
            } footer: {
                if !loginItem.isAvailable {
                    Text("Available when running the packaged VitalsMac.app.")
                } else if let message = loginItem.errorMessage {
                    Text(message)
                }
            }

            Section("Menu bar") {
                Toggle("CPU usage", isOn: $model.settings.showCPUUsage)
                Toggle("Hottest CPU temperature", isOn: $model.settings.showTemperature)
                Toggle("Fan speed", isOn: $model.settings.showFan)
            }

            Section {
                Toggle("Notify me when the Mac runs hot", isOn: $model.settings.alertsEnabled)

                Stepper(
                    value: $model.settings.alertThreshold,
                    in: AppSettings.thresholdRange,
                    step: 1
                ) {
                    LabeledContent("Alert at", value: "\(Int(model.settings.alertThreshold))°C")
                }
                .disabled(!model.settings.alertsEnabled)

                Stepper(
                    value: $model.settings.alertSustainSeconds,
                    in: AppSettings.sustainRange,
                    step: 5
                ) {
                    LabeledContent("If it stays that hot for", value: "\(Int(model.settings.alertSustainSeconds)) s")
                }
                .disabled(!model.settings.alertsEnabled)

                Stepper(
                    value: $model.settings.alertCooldownMinutes,
                    in: AppSettings.cooldownRange,
                    step: 1
                ) {
                    LabeledContent("Wait between alerts", value: "\(Int(model.settings.alertCooldownMinutes)) min")
                }
                .disabled(!model.settings.alertsEnabled)
            } header: {
                Text("Thermal alert")
            } footer: {
                Text("Alerts again only after the CPU has cooled 5°C below the alert temperature.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 400)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            // Menu-bar apps have no Dock icon, so bring the window forward explicitly.
            NSApp.activate(ignoringOtherApps: true)
            loginItem.refresh()
        }
    }
}
