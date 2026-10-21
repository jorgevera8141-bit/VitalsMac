import SensorKit
import SwiftUI

struct OverviewPage: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                healthCard
                HStack(alignment: .top, spacing: 16) {
                    storageCard
                    memoryCard
                }
                processorCard
                graphicsCard
                networkCard
            }
            .padding(20)
        }
        .navigationTitle("Overview")
    }

    // MARK: Health

    private var healthCard: some View {
        let score = model.health
        let tint = Self.tint(forScore: score.overall)
        return HStack(spacing: 24) {
            RingView(fraction: Double(score.overall) / 100, tint: tint, label: "\(score.overall)", lineWidth: 14)
                .frame(width: 120, height: 120)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Text("Health").font(.title.bold())
                    Text(score.label)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(tint.opacity(0.15), in: Capsule())
                        .foregroundStyle(tint)
                }
                Text(score.message).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    if let thermals = score.thermals { chip("Thermals", thermals) }
                    chip("Memory", score.memory)
                    chip("Disk", score.disk)
                }
            }
            Spacer(minLength: 0)
        }
        .cardStyle()
    }

    private func chip(_ name: String, _ value: Int) -> some View {
        HStack(spacing: 6) {
            Circle().fill(Self.tint(forScore: value)).frame(width: 7, height: 7)
            Text(name)
            Text("\(value)").fontWeight(.semibold).monospacedDigit()
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.primary.opacity(0.06), in: Capsule())
    }

    private static func tint(forScore score: Int) -> Color {
        switch score {
        case 70...: return .green
        case 50..<70: return .orange
        default: return .red
        }
    }

    // MARK: Storage and memory

    private var storageCard: some View {
        let metrics = model.metrics
        let free = metrics.diskTotal > metrics.diskUsed ? metrics.diskTotal - metrics.diskUsed : 0
        return Card(title: "Storage", symbol: "internaldrive", tint: .indigo, trailing: "\(Format.bytes(free)) free") {
            Text("\(Format.bytes(metrics.diskUsed)) of \(Format.bytes(metrics.diskTotal))")
                .font(.title2.weight(.semibold))
                .monospacedDigit()
            UsageBar(fraction: metrics.diskFraction, tint: .indigo)
        }
    }

    private var memoryCard: some View {
        let metrics = model.metrics
        return Card(title: "Memory", symbol: "memorychip", tint: .purple, trailing: Self.pressure(metrics.memoryFraction)) {
            Text("\(Format.bytes(metrics.memoryUsed)) of \(Format.bytes(metrics.memoryTotal))")
                .font(.title2.weight(.semibold))
                .monospacedDigit()
            UsageBar(fraction: metrics.memoryFraction, tint: .purple)
        }
    }

    private static func pressure(_ fraction: Double) -> String {
        switch fraction {
        case ..<0.80: return "Normal"
        case 0.80..<0.92: return "High"
        default: return "Critical"
        }
    }

    // MARK: Processor, graphics, network

    private var processorCard: some View {
        let metrics = model.metrics
        return Card(title: "Processor", symbol: "cpu", tint: .blue, trailing: "\(Format.percent(metrics.cpuTotal)) total") {
            HStack(spacing: 20) {
                RingView(fraction: metrics.cpuTotal, tint: .blue, label: Format.percent(metrics.cpuTotal))
                    .frame(width: 96, height: 96)
                VStack(alignment: .leading, spacing: 6) {
                    legend("User", Format.percent(metrics.cpuUser), .blue)
                    legend("System", Format.percent(metrics.cpuSystem), .cyan)
                }
                .frame(width: 120, alignment: .leading)
                HistoryChart(lines: [HistoryLine(id: "cpu", history: model.cpuHistory, tint: .blue)], yMax: 1)
            }
        }
    }

    private var graphicsCard: some View {
        let load = model.metrics.gpuLoad
        return Card(
            title: "Graphics", symbol: "display", tint: .orange,
            trailing: load.map { "\(Format.percent($0)) load" }
        ) {
            if let load {
                HStack(spacing: 20) {
                    RingView(fraction: load, tint: .orange, label: Format.percent(load))
                        .frame(width: 96, height: 96)
                    legend("GPU load", Format.percent(load), .orange)
                        .frame(width: 120, alignment: .leading)
                    HistoryChart(lines: [HistoryLine(id: "gpu", history: model.gpuHistory, tint: .orange)], yMax: 1)
                }
            } else {
                Text("This Mac doesn't report GPU load.").foregroundStyle(.secondary)
            }
        }
    }

    private var networkCard: some View {
        let metrics = model.metrics
        let peak = max(model.downloadHistory.peak, model.uploadHistory.peak)
        return Card(title: "Network", symbol: "arrow.up.arrow.down", tint: .teal, trailing: "peak \(Format.rate(bytesPerSecond: peak))") {
            HStack(spacing: 24) {
                Label(Format.rate(bytesPerSecond: metrics.networkDown), systemImage: "arrow.down")
                    .foregroundStyle(.teal)
                Label(Format.rate(bytesPerSecond: metrics.networkUp), systemImage: "arrow.up")
                    .foregroundStyle(.green)
            }
            .font(.title3.weight(.semibold))
            .monospacedDigit()
            HistoryChart(lines: [
                HistoryLine(id: "down", history: model.downloadHistory, tint: .teal),
                HistoryLine(id: "up", history: model.uploadHistory, tint: .green),
            ])
        }
    }

    private func legend(_ name: String, _ value: String, _ tint: Color) -> some View {
        HStack(spacing: 8) {
            Circle().fill(tint).frame(width: 8, height: 8)
            Text(value).font(.title3.weight(.semibold)).monospacedDigit()
            Text(name).foregroundStyle(.secondary)
        }
    }
}
