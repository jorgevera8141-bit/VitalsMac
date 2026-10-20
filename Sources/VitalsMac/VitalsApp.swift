import SensorKit
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var readings: [Reading] = []
    private let sampler = SystemSampler()
    private let alerter = ThermalAlerter()
    private let settings: SettingsModel
    private var timer: Timer?

    init(settings: SettingsModel) {
        self.settings = settings
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        readings = sampler.sample()
        alerter.update(with: readings, settings: settings.settings)
    }
}

@main
struct VitalsApp: App {
    @StateObject private var settings: SettingsModel
    @StateObject private var model: AppModel
    @StateObject private var loginItem = LoginItemModel()

    init() {
        let settings = SettingsModel()
        _settings = StateObject(wrappedValue: settings)
        _model = StateObject(wrappedValue: AppModel(settings: settings))
    }

    var body: some Scene {
        MenuBarExtra {
            ForEach(SensorGroup.allCases, id: \.self) { group in
                let rows = MenuBarSummary.split(model.readings, in: group)
                if !rows.primary.isEmpty || !rows.overflow.isEmpty {
                    Section(group.rawValue) {
                        ForEach(rows.primary) { reading in
                            Text("\(reading.label): \(reading.value)")
                        }
                        if !rows.overflow.isEmpty {
                            Menu("All sensors (\(rows.primary.count + rows.overflow.count))") {
                                ForEach(rows.primary + rows.overflow) { reading in
                                    Text("\(reading.label): \(reading.value)")
                                }
                            }
                        }
                    }
                }
            }
            Divider()
            SettingsLink { Text("Settings…") }
                .keyboardShortcut(",")
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        } label: {
            Text(MenuBarSummary.title(from: model.readings, options: settings.settings.titleOptions))
        }

        Settings {
            SettingsView(model: settings, loginItem: loginItem)
        }
    }
}
