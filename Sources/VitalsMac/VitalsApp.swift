import SensorKit
import SwiftUI

private enum WindowID {
    static let dashboard = "dashboard"
}

/// The dropdown that opens from the menu-bar title.
struct MenuContent: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open Dashboard") {
            // Menu-bar apps have no Dock icon, so bring the window forward explicitly.
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: WindowID.dashboard)
        }
        .keyboardShortcut("d")
        Divider()

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
            MenuContent(model: model)
        } label: {
            Text(MenuBarSummary.title(from: model.readings, options: settings.settings.titleOptions))
        }

        Window("VitalsMac", id: WindowID.dashboard) {
            DashboardView(model: model)
        }
        .defaultSize(width: 980, height: 760)
        // Only open from the menu, never at launch.
        .defaultLaunchBehavior(.suppressed)

        Settings {
            SettingsView(model: settings, loginItem: loginItem)
        }
    }
}
