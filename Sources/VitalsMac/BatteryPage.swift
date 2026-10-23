import SensorKit
import SwiftUI

struct BatteryPage: View {
    @ObservedObject var model: AppModel
    @State private var range: HistoryRange = .day

    private static let maxPoints = 300
    private static let lowChargeThreshold = 0.2
    /// Below this current the battery is neither meaningfully charging nor draining.
    private static let idleCurrentMA: Int64 = 50

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let battery = model.battery {
                    statusCard(battery)
                    healthCard(battery)
                    powerCard(battery)
                    historyCard
                } else {
                    noBatteryCard
                }
            }
            .padding(20)
        }
        .navigationTitle("Battery & Power")
    }

    private var noBatteryCard: some View {
        Card(title: "No battery", symbol: "powerplug", tint: .gray) {
            Text("This Mac doesn't have a battery, so there is nothing to show here.")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Status

    private func statusCard(_ battery: BatteryInfo) -> some View {
        let tint = Self.chargeTint(battery)
        return HStack(spacing: 24) {
            RingView(fraction: battery.chargeFraction, tint: tint, label: Format.percent(battery.chargeFraction), lineWidth: 14)
                .frame(width: 120, height: 120)
            VStack(alignment: .leading, spacing: 6) {
                Text(battery.stateLabel).font(.title.bold())
                if let minutes = battery.timeRemainingMinutes {
                    Text("\(Format.duration(Double(minutes) * 60)) \(battery.isCharging ? "until full" : "remaining")")
                        .foregroundStyle(.secondary)
                }
                if battery.isPluggedIn, let watts = battery.adapterWatts {
                    Label("\(watts) W power adapter", systemImage: "powerplug").foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .cardStyle()
    }

    private static func chargeTint(_ battery: BatteryInfo) -> Color {
        if battery.isCharging || battery.isPluggedIn { return .green }
        return battery.chargeFraction <= lowChargeThreshold ? .red : .green
    }

    // MARK: Health

    private func healthCard(_ battery: BatteryInfo) -> some View {
        Card(
            title: "Battery health", symbol: "waveform.path.ecg", tint: .pink,
            trailing: battery.healthFraction.map(BatteryInfo.healthDescription(for:))
        ) {
            if let health = battery.healthFraction {
                Text("\(Format.percent(health)) of original capacity")
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                UsageBar(fraction: health, tint: .pink)
            }
            VStack(spacing: 8) {
                if let maximum = battery.maxCapacityMAh, let design = battery.designCapacityMAh {
                    row("Capacity", "\(maximum.formatted()) of \(design.formatted()) mAh")
                }
                if let cycles = battery.cycleCount {
                    row("Charge cycles", cycles.formatted())
                }
                if let temperature = battery.temperatureC {
                    row("Temperature", String(format: "%.1f°C", temperature))
                }
            }
        }
    }

    // MARK: Power

    private func powerCard(_ battery: BatteryInfo) -> some View {
        Card(title: "Power", symbol: "bolt.fill", tint: .orange) {
            Text(Self.powerHeadline(battery))
                .font(.title2.weight(.semibold))
                .monospacedDigit()
            VStack(spacing: 8) {
                if let voltage = battery.voltageV {
                    row("Voltage", String(format: "%.2f V", voltage))
                }
                if let current = battery.amperageMA {
                    row("Current", "\(current.formatted()) mA")
                }
                row("Low Power Mode", ProcessInfo.processInfo.isLowPowerModeEnabled ? "On" : "Off")
            }
        }
    }

    private static func powerHeadline(_ battery: BatteryInfo) -> String {
        guard let watts = battery.powerWatts, let current = battery.amperageMA else { return "Power unavailable" }
        if abs(current) < idleCurrentMA { return "Idle" }
        let magnitude = String(format: "%.1f W", abs(watts))
        return watts > 0 ? "Charging at \(magnitude)" : "Using \(magnitude)"
    }

    // MARK: History

    private var historyCard: some View {
        let points = range.points(
            in: model.historyPoints.filter { $0.battery != nil }, now: Date(), maxPoints: Self.maxPoints
        )
        return Card(title: "Charge history", symbol: "chart.xyaxis.line", tint: .green, trailing: Self.rangeSummary(points)) {
            Picker("Range", selection: $range) {
                ForEach(HistoryRange.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if points.count < 2 {
                Text("Charge history is saved once a minute. Check back in a couple of minutes.")
                    .foregroundStyle(.secondary)
            } else {
                TimeSeriesChart(
                    points: points,
                    series: [HistorySeries(name: "Battery", tint: .green) { $0.battery }],
                    range: range,
                    format: { Format.percent($0) },
                    yDomain: 0...1,
                    filled: true,
                    maxGap: range.gapThreshold(maxPoints: Self.maxPoints)
                )
            }
        }
    }

    private static func rangeSummary(_ points: [HistoryPoint]) -> String {
        let levels = points.compactMap(\.battery)
        guard let low = levels.min(), let high = levels.max() else { return "" }
        return "low \(Format.percent(low)) · high \(Format.percent(high))"
    }

    private func row(_ title: String, _ value: String) -> some View {
        LabeledContent(title) {
            Text(value).monospacedDigit()
        }
    }
}
