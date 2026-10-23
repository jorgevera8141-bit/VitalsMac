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
    /// One averaged point per minute, kept for a week and saved across restarts.
    @Published private(set) var historyPoints: [HistoryPoint] = []
    /// Nil on Macs without a battery. Reading the registry entry is cheap, so it is refreshed every sample.
    @Published private(set) var battery: BatteryInfo?
    /// Every running process; only filled in while the Performance page is open.
    @Published private(set) var processes: [ProcessUsage] = []
    private var isProcessSamplingActive = false
    private var isProcessSampleInFlight = false

    private let sampler = SystemSampler()
    private let alerter = ThermalAlerter()
    private let settings: SettingsModel
    private let historyStore: HistoryStore
    private var aggregator = HistoryAggregator()
    private var timer: Timer?

    init(
        settings: SettingsModel,
        historyStore: HistoryStore = HistoryStore(fileURL: HistoryStore.defaultFileURL)
    ) {
        self.settings = settings
        self.historyStore = historyStore
        loadHistory()
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
        battery = BatteryReader.read()
        cpuHistory = cpuHistory.appending(snapshot.metrics.cpuTotal)
        if let gpu = snapshot.metrics.gpuLoad {
            gpuHistory = gpuHistory.appending(gpu)
        }
        downloadHistory = downloadHistory.appending(snapshot.metrics.networkDown)
        uploadHistory = uploadHistory.appending(snapshot.metrics.networkUp)
        alerter.update(with: readings, settings: settings.settings)
        record(snapshot.metrics)
        if isProcessSamplingActive { sampleProcesses() }
    }

    // MARK: Processes

    /// The process list costs a `ps` run, so it is only sampled while someone is looking at it.
    func setProcessSampling(_ active: Bool) {
        isProcessSamplingActive = active
        if active {
            sampleProcesses()
        } else {
            processes = []
        }
    }

    private func sampleProcesses() {
        guard !isProcessSampleInFlight else { return }
        isProcessSampleInFlight = true
        Task {
            let result = await Task.detached(priority: .utility) { ProcessSampler.sample() }.value
            isProcessSampleInFlight = false
            if isProcessSamplingActive { processes = result }
        }
    }

    // MARK: History

    private func loadHistory() {
        let cutoff = Date().addingTimeInterval(-HistoryStore.retention)
        historyPoints = historyStore.load(since: cutoff)
        // Rewriting on launch drops expired and unreadable lines so the file can't grow without bound.
        do {
            try historyStore.rewrite(historyPoints)
        } catch {
            NSLog("Vitals: could not compact history: \(error)")
        }
    }

    private func record(_ metrics: Metrics, at now: Date = Date()) {
        let result = aggregator.adding(metrics, at: now)
        aggregator = result.aggregator
        guard let point = result.completed else { return }

        let cutoff = now.addingTimeInterval(-HistoryStore.retention)
        historyPoints = historyPoints.filter { $0.time >= cutoff } + [point]
        do {
            try historyStore.append(point)
        } catch {
            NSLog("Vitals: could not save history point: \(error)")
        }
    }
}
