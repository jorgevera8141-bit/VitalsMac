import Foundation
import ServiceManagement

/// Wraps "launch at login". The system's login-item list is the source of truth,
/// so nothing is stored in our own settings.
@MainActor
final class LoginItemModel: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var errorMessage: String?

    /// Login items only work for a packaged app, not a bare `swift run` binary.
    let isAvailable = Bundle.main.bundleIdentifier != nil

    init() {
        refresh()
    }

    func refresh() {
        guard isAvailable else { return }
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        guard isAvailable else { return }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            errorMessage = nil
        } catch {
            errorMessage = "Could not change launch at login: \(error.localizedDescription)"
        }
        refresh()
    }
}
