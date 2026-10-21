import Charts
import SensorKit
import SwiftUI

private let cardRadius: CGFloat = 14

extension View {
    func cardStyle() -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: cardRadius))
            .overlay(RoundedRectangle(cornerRadius: cardRadius).stroke(Color.primary.opacity(0.08)))
    }
}

/// A titled panel with a tinted icon and an optional right-aligned caption.
struct Card<Content: View>: View {
    let title: String
    let symbol: String
    let tint: Color
    var trailing: String?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
                Text(title).font(.headline)
                Spacer()
                if let trailing {
                    Text(trailing).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            content()
        }
        .cardStyle()
    }
}

struct RingView: View {
    let fraction: Double
    let tint: Color
    let label: String
    var lineWidth: CGFloat = 12

    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(fraction, 0), 1)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.4), value: fraction)
            Text(label)
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .monospacedDigit()
        }
        .padding(lineWidth / 2)
    }
}

struct UsageBar: View {
    let fraction: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(tint.opacity(0.15))
                Capsule()
                    .fill(tint)
                    .frame(width: proxy.size.width * CGFloat(min(max(fraction, 0), 1)))
                    .animation(.easeOut(duration: 0.4), value: fraction)
            }
        }
        .frame(height: 8)
    }
}

struct HistoryLine: Identifiable {
    let id: String
    let history: SeriesHistory
    let tint: Color
}

/// A sparkline-style area chart over one or more rolling series.
struct HistoryChart: View {
    let lines: [HistoryLine]
    /// Fixed upper bound of the y axis; nil scales to the data.
    var yMax: Double?
    var height: CGFloat = 70

    private var resolvedMax: Double {
        yMax ?? max(lines.map(\.history.peak).max() ?? 0, 1) * 1.2
    }

    private var xMax: Int {
        max((lines.first?.history.capacity ?? 2) - 1, 1)
    }

    var body: some View {
        Chart {
            ForEach(lines) { line in
                ForEach(Array(line.history.values.enumerated()), id: \.offset) { index, value in
                    AreaMark(
                        x: .value("Time", index),
                        y: .value("Value", value),
                        series: .value("Series", line.id),
                        stacking: .unstacked
                    )
                    .foregroundStyle(line.tint.opacity(0.15))
                    LineMark(
                        x: .value("Time", index),
                        y: .value("Value", value),
                        series: .value("Series", line.id)
                    )
                    .foregroundStyle(line.tint)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartXScale(domain: 0...xMax)
        .chartYScale(domain: 0...resolvedMax)
        .frame(height: height)
    }
}
