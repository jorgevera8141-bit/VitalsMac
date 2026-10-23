import Foundation

/// One minute of readings, averaged. This is what gets saved to disk and charted.
public struct HistoryPoint: Codable, Equatable, Sendable, Identifiable {
    public let time: Date
    public let cpu: Double
    public let gpu: Double?
    public let temperature: Double?
    public let fanRPM: Double?
    public let memory: Double
    public let networkDown: Double
    public let networkUp: Double
    /// Battery charge (0...1); nil on Macs without a battery and in points saved before it was recorded.
    public let battery: Double?

    public var id: Date { time }

    public init(
        time: Date, cpu: Double, gpu: Double?, temperature: Double?, fanRPM: Double?,
        memory: Double, networkDown: Double, networkUp: Double, battery: Double? = nil
    ) {
        self.time = time
        self.cpu = cpu
        self.gpu = gpu
        self.temperature = temperature
        self.fanRPM = fanRPM
        self.memory = memory
        self.networkDown = networkDown
        self.networkUp = networkUp
        self.battery = battery
    }
}

/// Averages live samples into one `HistoryPoint` per bucket. Value type: each call returns the next state.
public struct HistoryAggregator: Sendable {
    public let bucketSeconds: TimeInterval
    private let bucket: Bucket?

    public init(bucketSeconds: TimeInterval = 60) {
        self.init(bucketSeconds: bucketSeconds, bucket: nil)
    }

    private init(bucketSeconds: TimeInterval, bucket: Bucket?) {
        self.bucketSeconds = bucketSeconds
        self.bucket = bucket
    }

    /// Adds a sample. `completed` is the finished bucket's average when this sample starts a new bucket.
    public func adding(_ metrics: Metrics, at time: Date) -> (aggregator: HistoryAggregator, completed: HistoryPoint?) {
        guard let bucket else {
            return (next(Bucket(start: time).adding(metrics)), nil)
        }
        if time.timeIntervalSince(bucket.start) >= bucketSeconds {
            return (next(Bucket(start: time).adding(metrics)), bucket.point)
        }
        return (next(bucket.adding(metrics)), nil)
    }

    private func next(_ bucket: Bucket) -> HistoryAggregator {
        HistoryAggregator(bucketSeconds: bucketSeconds, bucket: bucket)
    }

    /// Mean over only the values that were present.
    private struct RunningAverage: Sendable {
        var total = 0.0
        var count = 0

        func adding(_ value: Double?) -> RunningAverage {
            guard let value else { return self }
            return RunningAverage(total: total + value, count: count + 1)
        }

        var average: Double? { count == 0 ? nil : total / Double(count) }
    }

    private struct Bucket: Sendable {
        let start: Date
        var count = 0
        var cpu = 0.0
        var memory = 0.0
        var down = 0.0
        var up = 0.0
        var gpu = RunningAverage()
        var temperature = RunningAverage()
        var fan = RunningAverage()
        var battery = RunningAverage()

        init(start: Date) {
            self.start = start
        }

        func adding(_ metrics: Metrics) -> Bucket {
            var copy = self
            copy.count += 1
            copy.cpu += metrics.cpuTotal
            copy.memory += metrics.memoryFraction
            copy.down += metrics.networkDown
            copy.up += metrics.networkUp
            copy.gpu = gpu.adding(metrics.gpuLoad)
            copy.temperature = temperature.adding(metrics.hottestCPU)
            copy.fan = fan.adding(metrics.fastestFan)
            copy.battery = battery.adding(metrics.batteryCharge)
            return copy
        }

        var point: HistoryPoint {
            let samples = Double(max(count, 1))
            return HistoryPoint(
                time: start, cpu: cpu / samples, gpu: gpu.average, temperature: temperature.average,
                fanRPM: fan.average, memory: memory / samples, networkDown: down / samples, networkUp: up / samples,
                battery: battery.average
            )
        }
    }
}
