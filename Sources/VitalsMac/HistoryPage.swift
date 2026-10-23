import Charts
import SensorKit
import SwiftUI

/// One plotted line: a name, a color and how to read its value from a history point.
struct HistorySeries: Identifiable {
    let name: String
    let tint: Color
    let value: (HistoryPoint) -> Double?

    var id: String { name }
}

struct HistoryPage: View {
    @ObservedObject var model: AppModel
    @State private var range: HistoryRange = .hour

    private static let maxPoints = 300

    private var points: [HistoryPoint] {
        range.points(in: model.historyPoints, now: Date(), maxPoints: Self.maxPoints)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Picker("Range", selection: $range) {
                    ForEach(HistoryRange.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if points.count < 2 {
                    emptyState
                } else {
                    charts
                }
            }
            .padding(20)
        }
        .navigationTitle("History")
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Collecting data…", systemImage: "clock.arrow.circlepath").font(.headline)
            Text("History is saved once a minute and kept for 7 days, even after you quit the app. "
                + "Check back in a couple of minutes.")
                .foregroundStyle(.secondary)
            Text("\(model.historyPoints.count) points saved so far")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .cardStyle()
    }

    private var charts: some View {
        let points = self.points
        return VStack(spacing: 16) {
            chartCard("Processor", "cpu", .blue, points, [HistorySeries(name: "CPU", tint: .blue) { $0.cpu }],
                      format: { Format.percent($0) }, yDomain: 0...1)
            if points.contains(where: { $0.gpu != nil }) {
                chartCard("Graphics", "display", .orange, points,
                          [HistorySeries(name: "GPU", tint: .orange) { $0.gpu }],
                          format: { Format.percent($0) }, yDomain: 0...1)
            }
            if points.contains(where: { $0.temperature != nil }) {
                chartCard("Temperature", "thermometer.medium", .red, points,
                          [HistorySeries(name: "CPU temperature", tint: .red) { $0.temperature }],
                          format: { String(format: "%.0f°C", $0) }, filled: false)
            }
            if points.contains(where: { $0.fanRPM != nil }) {
                chartCard("Fans", "fanblades", .mint, points,
                          [HistorySeries(name: "Fastest fan", tint: .mint) { $0.fanRPM }],
                          format: { String(format: "%.0f rpm", $0) }, filled: false)
            }
            chartCard("Memory", "memorychip", .purple, points,
                      [HistorySeries(name: "Memory", tint: .purple) { $0.memory }],
                      format: { Format.percent($0) }, yDomain: 0...1)
            chartCard("Network", "arrow.up.arrow.down", .teal, points,
                      [HistorySeries(name: "Download", tint: .teal) { $0.networkDown },
                       HistorySeries(name: "Upload", tint: .green) { $0.networkUp }],
                      format: { Format.rate(bytesPerSecond: $0) })
        }
    }

    private func chartCard(
        _ title: String, _ symbol: String, _ tint: Color, _ points: [HistoryPoint],
        _ series: [HistorySeries], format: @escaping (Double) -> String,
        yDomain: ClosedRange<Double>? = nil, filled: Bool = true
    ) -> some View {
        Card(title: title, symbol: symbol, tint: tint, trailing: Self.summary(points, series, format)) {
            TimeSeriesChart(
                points: points, series: series, range: range, format: format, yDomain: yDomain,
                filled: filled, maxGap: range.gapThreshold(maxPoints: Self.maxPoints)
            )
        }
    }

    private static func summary(
        _ points: [HistoryPoint], _ series: [HistorySeries], _ format: (Double) -> String
    ) -> String {
        if series.count == 1, let only = series.first {
            let values = points.compactMap(only.value)
            guard let peak = values.max() else { return "" }
            let average = values.reduce(0, +) / Double(values.count)
            return "avg \(format(average)) · peak \(format(peak))"
        }
        return series.compactMap { item in
            points.compactMap(item.value).max().map { "\(item.name) peak \(format($0))" }
        }.joined(separator: "  ")
    }
}

struct TimeSeriesChart: View {
    let points: [HistoryPoint]
    let series: [HistorySeries]
    let range: HistoryRange
    let format: (Double) -> String
    let yDomain: ClosedRange<Double>?
    let filled: Bool
    let maxGap: TimeInterval

    /// A continuous stretch of one series; gaps (app closed, Mac asleep) start a new run so no line crosses them.
    private struct Run: Identifiable {
        let id: String
        let series: HistorySeries
        let points: [HistoryPoint]
    }

    private var runs: [Run] {
        series.flatMap { item -> [Run] in
            let present = points.filter { item.value($0) != nil }
            let pieces = HistoryRange.segments(present, maxGap: maxGap)
            return pieces.enumerated().map { index, piece in
                Run(id: "\(item.name)-\(index)", series: item, points: piece)
            }
        }
    }

    var body: some View {
        let now = Date()
        let allRuns = runs
        Chart {
            ForEach(allRuns) { run in
                ForEach(run.points) { point in
                    marks(run, point)
                }
            }
        }
        .chartXScale(domain: now.addingTimeInterval(-range.window)...now)
        .modifier(YScale(domain: yDomain))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) {
                AxisGridLine()
                AxisValueLabel(format: range == .week
                    ? Date.FormatStyle().weekday(.abbreviated).day()
                    : Date.FormatStyle().hour().minute())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let number = value.as(Double.self) { Text(format(number)) }
                }
            }
        }
        .frame(height: 150)
    }

    @ChartContentBuilder
    private func marks(_ run: Run, _ point: HistoryPoint) -> some ChartContent {
        if let value = run.series.value(point) {
            if filled {
                AreaMark(
                    x: .value("Time", point.time),
                    y: .value(run.series.name, value),
                    series: .value("Run", run.id),
                    stacking: .unstacked
                )
                .foregroundStyle(run.series.tint.opacity(0.15))
            }
            LineMark(
                x: .value("Time", point.time),
                y: .value(run.series.name, value),
                series: .value("Run", run.id)
            )
            .foregroundStyle(run.series.tint)
            .lineStyle(StrokeStyle(lineWidth: 2))
        }
    }
}

/// Fixed y range when given, otherwise a range fitted to the data without forcing zero.
private struct YScale: ViewModifier {
    let domain: ClosedRange<Double>?

    func body(content: Content) -> some View {
        if let domain {
            content.chartYScale(domain: domain)
        } else {
            content.chartYScale(domain: .automatic(includesZero: false))
        }
    }
}
