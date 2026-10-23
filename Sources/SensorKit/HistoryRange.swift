import Foundation

/// The time windows the history page can show.
public enum HistoryRange: String, CaseIterable, Identifiable, Sendable {
    case hour = "1 hour"
    case day = "24 hours"
    case week = "7 days"

    public var id: String { rawValue }

    public var window: TimeInterval {
        switch self {
        case .hour: return 3_600
        case .day: return 86_400
        case .week: return 604_800
        }
    }

    /// How far apart two points can be before a chart should break the line (e.g. the Mac was asleep).
    public func gapThreshold(maxPoints: Int) -> TimeInterval {
        max(300, window / Double(max(maxPoints, 1)) * 3)
    }

    /// Splits time-ordered points into runs with no gap larger than `maxGap`.
    public static func segments(_ points: [HistoryPoint], maxGap: TimeInterval) -> [[HistoryPoint]] {
        points.reduce(into: [[HistoryPoint]]()) { runs, point in
            guard let last = runs.last?.last, point.time.timeIntervalSince(last.time) <= maxGap else {
                runs.append([point])
                return
            }
            runs[runs.count - 1].append(point)
        }
    }

    /// Points inside this window, thinned to at most `maxPoints` so charts stay light.
    public func points(in all: [HistoryPoint], now: Date, maxPoints: Int) -> [HistoryPoint] {
        let cutoff = now.addingTimeInterval(-window)
        return Self.downsample(all.filter { $0.time >= cutoff }, maxPoints: maxPoints)
    }

    /// Averages consecutive points into buckets so no more than `maxPoints` remain.
    public static func downsample(_ points: [HistoryPoint], maxPoints: Int) -> [HistoryPoint] {
        guard maxPoints > 0, points.count > maxPoints else { return points }
        let bucketSize = Int((Double(points.count) / Double(maxPoints)).rounded(.up))
        return stride(from: 0, to: points.count, by: bucketSize).map { start in
            average(Array(points[start..<min(start + bucketSize, points.count)]))
        }
    }

    private static func average(_ bucket: [HistoryPoint]) -> HistoryPoint {
        let count = Double(bucket.count)
        let first = bucket[0].time.timeIntervalSince1970
        let last = bucket[bucket.count - 1].time.timeIntervalSince1970
        return HistoryPoint(
            time: Date(timeIntervalSince1970: (first + last) / 2),
            cpu: bucket.map(\.cpu).reduce(0, +) / count,
            gpu: optionalAverage(bucket.map(\.gpu)),
            temperature: optionalAverage(bucket.map(\.temperature)),
            fanRPM: optionalAverage(bucket.map(\.fanRPM)),
            memory: bucket.map(\.memory).reduce(0, +) / count,
            networkDown: bucket.map(\.networkDown).reduce(0, +) / count,
            networkUp: bucket.map(\.networkUp).reduce(0, +) / count,
            battery: optionalAverage(bucket.map(\.battery))
        )
    }

    private static func optionalAverage(_ values: [Double?]) -> Double? {
        let present = values.compactMap { $0 }
        return present.isEmpty ? nil : present.reduce(0, +) / Double(present.count)
    }
}
