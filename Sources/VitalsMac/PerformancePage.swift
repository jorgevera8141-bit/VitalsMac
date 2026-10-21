import SensorKit
import SwiftUI

struct PerformancePage: View {
    @ObservedObject var model: AppModel
    @State private var sort: ProcessSort = .cpu

    private static let processLimit = 10
    private static let hotCoreThreshold = 0.9

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                coresCard
                summaryCard
                processesCard
            }
            .padding(20)
        }
        .navigationTitle("Performance")
        // `ps` only runs while this page is on screen.
        .onAppear { model.setProcessSampling(true) }
        .onDisappear { model.setProcessSampling(false) }
    }

    // MARK: Cores

    private var coresCard: some View {
        let usage = model.metrics.perCoreUsage
        return Card(title: "Cores", symbol: "cpu", tint: .blue, trailing: "\(Format.percent(model.metrics.cpuTotal)) total") {
            if usage.isEmpty {
                Text("Measuring…").foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 16)], spacing: 10) {
                    ForEach(Array(usage.enumerated()), id: \.offset) { index, value in
                        HStack(spacing: 10) {
                            Text("Core \(index + 1)")
                                .foregroundStyle(.secondary)
                                .frame(width: 56, alignment: .leading)
                            UsageBar(fraction: value, tint: value > Self.hotCoreThreshold ? .red : .blue)
                            Text(Format.percent(value))
                                .monospacedDigit()
                                .frame(width: 44, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }

    // MARK: Load and thermals

    private var summaryCard: some View {
        Card(title: "Load and thermals", symbol: "gauge", tint: .orange) {
            VStack(spacing: 8) {
                summaryRow("Load average (1 min)", .processor, "Load (1m)")
                summaryRow("Load average (5 min)", .processor, "Load (5m)")
                summaryRow("Logical cores", .processor, "Cores")
                summaryRow("Thermal state", .system, "Thermal state")
                summaryRow("Uptime", .system, "Uptime")
            }
        }
    }

    private func summaryRow(_ title: String, _ group: SensorGroup, _ label: String) -> some View {
        let value = model.readings.first { $0.group == group && $0.label == label }?.value ?? "–"
        return LabeledContent(title) {
            Text(value).monospacedDigit()
        }
    }

    // MARK: Processes

    private var processesCard: some View {
        let rows = ProcessListParser.top(model.processes, by: sort, limit: Self.processLimit)
        let largest = rows.first.map { value(of: $0) } ?? 0
        return Card(title: "Top processes", symbol: "list.number", tint: .teal, trailing: "\(model.processes.count) running") {
            Picker("Sort by", selection: $sort) {
                ForEach(ProcessSort.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if rows.isEmpty {
                Text("Loading…").foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(rows) { process in
                        HStack(spacing: 10) {
                            Text(process.name)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            UsageBar(fraction: largest > 0 ? value(of: process) / largest : 0, tint: .teal)
                                .frame(width: 120)
                            Text(label(of: process))
                                .monospacedDigit()
                                .frame(width: 84, alignment: .trailing)
                        }
                    }
                }
                Text("CPU is a recent average measured per core, so a busy process can show more than 100%.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func value(of process: ProcessUsage) -> Double {
        switch sort {
        case .cpu: return process.cpuPercent
        case .memory: return Double(process.memoryBytes)
        }
    }

    private func label(of process: ProcessUsage) -> String {
        switch sort {
        case .cpu: return String(format: "%.1f%%", process.cpuPercent)
        case .memory: return Format.bytes(process.memoryBytes)
        }
    }
}
