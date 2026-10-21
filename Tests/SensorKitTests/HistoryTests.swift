import XCTest
@testable import SensorKit

final class HistoryTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    private func metrics(
        cpu: Double, gpu: Double? = nil, temp: Double? = nil, fan: Double? = nil,
        memory: Double = 0.5, down: Double = 0, up: Double = 0
    ) -> Metrics {
        var value = Metrics()
        value.cpuUser = cpu
        value.gpuLoad = gpu
        value.hottestCPU = temp
        value.fastestFan = fan
        value.memoryUsed = UInt64(memory * 100)
        value.memoryTotal = 100
        value.networkDown = down
        value.networkUp = up
        return value
    }

    private func point(_ seconds: TimeInterval, cpu: Double = 0.5, temp: Double? = nil) -> HistoryPoint {
        HistoryPoint(
            time: t0.addingTimeInterval(seconds), cpu: cpu, gpu: nil, temperature: temp, fanRPM: nil,
            memory: 0.5, networkDown: 0, networkUp: 0
        )
    }

    // MARK: Aggregator

    func testNoPointUntilTheBucketHasElapsed() {
        var aggregator = HistoryAggregator(bucketSeconds: 60)
        for seconds in [0, 20, 40] as [TimeInterval] {
            let result = aggregator.adding(metrics(cpu: 0.2), at: t0.addingTimeInterval(seconds))
            XCTAssertNil(result.completed)
            aggregator = result.aggregator
        }
    }

    func testEmitsTheAverageWhenTheBucketCompletes() throws {
        var aggregator = HistoryAggregator(bucketSeconds: 60)
        for (seconds, cpu) in [(0.0, 0.2), (20, 0.4), (40, 0.6)] {
            aggregator = aggregator.adding(metrics(cpu: cpu), at: t0.addingTimeInterval(seconds)).aggregator
        }

        let result = aggregator.adding(metrics(cpu: 0.9), at: t0.addingTimeInterval(60))

        let completed = try XCTUnwrap(result.completed)
        XCTAssertEqual(completed.cpu, 0.4, accuracy: 0.0001)
        XCTAssertEqual(completed.time, t0)
    }

    func testOptionalFieldsAverageOverPresentSamplesOnly() throws {
        var aggregator = HistoryAggregator(bucketSeconds: 60)
        for (seconds, temp) in [(0.0, 80.0 as Double?), (20, nil), (40, 90)] {
            aggregator = aggregator.adding(metrics(cpu: 0.1, temp: temp), at: t0.addingTimeInterval(seconds)).aggregator
        }

        let completed = try XCTUnwrap(aggregator.adding(metrics(cpu: 0.1), at: t0.addingTimeInterval(60)).completed)

        XCTAssertEqual(try XCTUnwrap(completed.temperature), 85, accuracy: 0.0001)
        XCTAssertNil(completed.gpu)
    }

    func testTheTriggeringSampleStartsTheNextBucket() throws {
        var aggregator = HistoryAggregator(bucketSeconds: 60)
        aggregator = aggregator.adding(metrics(cpu: 0.1), at: t0).aggregator
        aggregator = aggregator.adding(metrics(cpu: 0.9), at: t0.addingTimeInterval(60)).aggregator
        aggregator = aggregator.adding(metrics(cpu: 0.5), at: t0.addingTimeInterval(90)).aggregator

        let completed = try XCTUnwrap(aggregator.adding(metrics(cpu: 0.1), at: t0.addingTimeInterval(120)).completed)

        XCTAssertEqual(completed.cpu, 0.7, accuracy: 0.0001)
        XCTAssertEqual(completed.time, t0.addingTimeInterval(60))
    }

    // MARK: Store

    private func makeStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("VitalsMacTests-\(UUID().uuidString)")
            .appendingPathComponent("history.jsonl")
    }

    private func cleanUp(_ url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    func testStoreRoundTripsPoints() throws {
        let url = makeStoreURL()
        defer { cleanUp(url) }
        let store = HistoryStore(fileURL: url)
        let points = [point(0, cpu: 0.1, temp: 70), point(60, cpu: 0.2)]

        for item in points { try store.append(item) }

        XCTAssertEqual(store.load(since: t0.addingTimeInterval(-1)), points)
    }

    func testStoreLoadsNothingWhenFileIsMissing() {
        XCTAssertEqual(HistoryStore(fileURL: makeStoreURL()).load(since: t0), [])
    }

    func testStoreLoadFiltersPointsOlderThanTheCutoff() throws {
        let url = makeStoreURL()
        defer { cleanUp(url) }
        let store = HistoryStore(fileURL: url)
        try store.append(point(0))
        try store.append(point(100))

        let loaded = store.load(since: t0.addingTimeInterval(50))

        XCTAssertEqual(loaded.map(\.time), [t0.addingTimeInterval(100)])
    }

    func testStoreSkipsCorruptLinesAndKeepsTheRest() throws {
        let url = makeStoreURL()
        defer { cleanUp(url) }
        let store = HistoryStore(fileURL: url)
        try store.append(point(0))
        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("not json\n".utf8))
        try handle.close()
        try store.append(point(60))

        XCTAssertEqual(store.load(since: t0.addingTimeInterval(-1)).count, 2)
    }

    func testStoreLoadSortsByTime() throws {
        let url = makeStoreURL()
        defer { cleanUp(url) }
        let store = HistoryStore(fileURL: url)
        try store.append(point(60))
        try store.append(point(0))

        XCTAssertEqual(store.load(since: t0.addingTimeInterval(-1)).map(\.time), [t0, t0.addingTimeInterval(60)])
    }

    func testRewriteReplacesFileContents() throws {
        let url = makeStoreURL()
        defer { cleanUp(url) }
        let store = HistoryStore(fileURL: url)
        try store.append(point(0))
        try store.append(point(60))

        try store.rewrite([point(60)])

        XCTAssertEqual(store.load(since: t0.addingTimeInterval(-1)).map(\.time), [t0.addingTimeInterval(60)])
    }

    // MARK: Range

    func testRangeKeepsOnlyPointsInsideTheWindow() {
        let now = t0.addingTimeInterval(10_000)
        let old = point(10_000 - 7_200)
        let recent = point(10_000 - 1_800)

        let result = HistoryRange.hour.points(in: [old, recent], now: now, maxPoints: 100)

        XCTAssertEqual(result, [recent])
    }

    func testDownsamplingLimitsPointCountAndAveragesEachBucket() {
        let points = (0..<100).map { point(Double($0) * 60, cpu: Double($0)) }

        let result = HistoryRange.downsample(points, maxPoints: 10)

        XCTAssertLessThanOrEqual(result.count, 10)
        XCTAssertEqual(result[0].cpu, 4.5, accuracy: 0.0001)
    }

    func testDownsamplingPassesSmallSeriesThrough() {
        let points = (0..<5).map { point(Double($0) * 60) }
        XCTAssertEqual(HistoryRange.downsample(points, maxPoints: 10), points)
    }

    func testDownsamplingKeepsOptionalFieldNilWhenAbsentInBucket() {
        let points = (0..<20).map { point(Double($0) * 60) }
        XCTAssertTrue(HistoryRange.downsample(points, maxPoints: 5).allSatisfy { $0.temperature == nil })
    }

    func testRangeWindowsAreOneHourOneDayOneWeek() {
        XCTAssertEqual(HistoryRange.hour.window, 3_600)
        XCTAssertEqual(HistoryRange.day.window, 86_400)
        XCTAssertEqual(HistoryRange.week.window, 604_800)
    }

    // MARK: Segments

    func testSegmentsSplitWhereTheGapIsTooLarge() {
        let points = [0, 60, 120, 1_000, 1_060].map { point(Double($0)) }

        let segments = HistoryRange.segments(points, maxGap: 300)

        XCTAssertEqual(segments.map { $0.map(\.time.timeIntervalSince1970) }.map(\.count), [3, 2])
        XCTAssertEqual(segments[1][0].time, t0.addingTimeInterval(1_000))
    }

    func testSegmentsKeepContinuousPointsTogether() {
        let points = (0..<5).map { point(Double($0) * 60) }
        XCTAssertEqual(HistoryRange.segments(points, maxGap: 300).count, 1)
    }

    func testSegmentsOfNothingIsEmpty() {
        XCTAssertEqual(HistoryRange.segments([], maxGap: 300).count, 0)
    }

    func testGapThresholdScalesWithDownsampling() {
        XCTAssertEqual(HistoryRange.hour.gapThreshold(maxPoints: 300), 300)
        XCTAssertEqual(HistoryRange.week.gapThreshold(maxPoints: 300), 6_048, accuracy: 0.0001)
    }
}
