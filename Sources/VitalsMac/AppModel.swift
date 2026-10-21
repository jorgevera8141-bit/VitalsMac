import Foundation
import SensorKit

/// Samples the system on a timer and keeps the latest values plus short histories for charts.
@MainActor
final class AppModel: ObservableObject {
    static let sampleInterval: TimeInterval = 2
    /// 90 samples at 2 s is three minutes of history.
    static let historyLength = 90

    @Published private(set) var readings: [Reading] = []
    @Published private(set) var metrics = Metrics()
    @Published private(set) var cpuHistory = SeriesHistory(capacity: historyLength)
    @Published private(set) var gpuHistory = SeriesHistory(capacity: historyLength)
    @Published private(set) var downloadHistory = SeriesHistory(capacity: historyLength)
    @Published private(set) var uploadHistory = SeriesHistory(capacity: historyLength)

    private let sampler = SystemSampler()
    private let alerter = ThermalAlerter()
    private let settings: SettingsModel
    private var timer: Timer?

    init(settings: SettingsModel) {
        self.settings = settings
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: Self.sampleInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    var health: HealthScore {
        HealthScore.compute(metrics.healthInputs)
    }

    func refresh() {
        let snapshot = sampler.sampleSnapshot()
        readings = snapshot.readings
        metrics = snapshot.metrics
        cpuHistory = cpuHistory.appending(snapshot.metrics.cpuTotal)
        if let gpu = snapshot.metrics.gpuLoad {
            gpuHistory = gpuHistory.appending(gpu)
        }
        downloadHistory = downloadHistory.appending(snapshot.metrics.networkDown)
        uploadHistory = uploadHistory.appending(snapshot.metrics.networkUp)
        alerter.update(with: readings, settings: settings.settings)
    }
}
