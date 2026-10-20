import Foundation
import IOKit.ps

/// Reads live system values. Holds the previous CPU and network samples so
/// each call can report usage and throughput since the last call.
public final class SystemSampler {
    private var lastTicks: CPUTicks?
    private var lastNetwork: NetworkCounters?
    private var lastSampleDate: Date?
    private let smc = SMCReader()

    public init() {}

    public func sample() -> [Reading] {
        let now = Date()
        let interval = lastSampleDate.map { now.timeIntervalSince($0) } ?? 0
        defer { lastSampleDate = now }

        return processor()
            + smc.readings()
            + memory()
            + storage()
            + network(interval: interval)
            + battery()
            + system()
    }

    // MARK: Processor

    private func processor() -> [Reading] {
        guard let ticks = Self.readCPUTicks() else { return [] }
        defer { lastTicks = ticks }

        let usage = lastTicks.map { Calculations.cpuUsage(previous: $0, current: ticks) } ?? 0
        let load = Self.loadAverages()
        return [
            Reading(group: .processor, label: "Usage", value: Format.percent(usage)),
            Reading(group: .processor, label: "Load (1m)", value: String(format: "%.2f", load.0)),
            Reading(group: .processor, label: "Load (5m)", value: String(format: "%.2f", load.1)),
            Reading(group: .processor, label: "Cores", value: "\(ProcessInfo.processInfo.activeProcessorCount)"),
        ]
    }

    static func readCPUTicks() -> CPUTicks? {
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        var info = host_cpu_load_info_data_t()
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return CPUTicks(
            user: UInt64(info.cpu_ticks.0),
            system: UInt64(info.cpu_ticks.1),
            idle: UInt64(info.cpu_ticks.2),
            nice: UInt64(info.cpu_ticks.3)
        )
    }

    static func loadAverages() -> (Double, Double, Double) {
        var loads = [Double](repeating: 0, count: 3)
        getloadavg(&loads, 3)
        return (loads[0], loads[1], loads[2])
    }

    // MARK: Memory

    private func memory() -> [Reading] {
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var stats = vm_statistics64_data_t()
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return [] }

        let page = UInt64(vm_kernel_page_size)
        let total = ProcessInfo.processInfo.physicalMemory
        let used = (UInt64(stats.active_count) + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)) * page
        let free = UInt64(stats.free_count) * page
        return [
            Reading(group: .memory, label: "Used", value: Format.bytes(used)),
            Reading(group: .memory, label: "Free", value: Format.bytes(free)),
            Reading(group: .memory, label: "Total", value: Format.bytes(total)),
            Reading(group: .memory, label: "Usage", value: Format.percent(Double(used) / Double(total))),
        ]
    }

    // MARK: Storage

    private func storage() -> [Reading] {
        let url = URL(fileURLWithPath: "/")
        guard
            let values = try? url.resourceValues(forKeys: [
                .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey,
            ]),
            let total = values.volumeTotalCapacity,
            let available = values.volumeAvailableCapacityForImportantUsage
        else { return [] }

        let free = UInt64(max(0, available))
        let size = UInt64(total)
        let used = size > free ? size - free : 0
        return [
            Reading(group: .storage, label: "Used", value: Format.bytes(used)),
            Reading(group: .storage, label: "Free", value: Format.bytes(free)),
            Reading(group: .storage, label: "Total", value: Format.bytes(size)),
        ]
    }

    // MARK: Network

    private func network(interval: TimeInterval) -> [Reading] {
        let counters = Self.readNetworkCounters()
        defer { lastNetwork = counters }

        let rate = lastNetwork.map { Calculations.networkRate(previous: $0, current: counters, interval: interval) }
            ?? (down: 0, up: 0)
        return [
            Reading(group: .network, label: "Download", value: Format.rate(bytesPerSecond: rate.down)),
            Reading(group: .network, label: "Upload", value: Format.rate(bytesPerSecond: rate.up)),
        ]
    }

    /// Sums byte counters across physical-looking interfaces (en*), skipping loopback and tunnels.
    static func readNetworkCounters() -> NetworkCounters {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return NetworkCounters(received: 0, sent: 0) }
        defer { freeifaddrs(head) }

        var received: UInt64 = 0
        var sent: UInt64 = 0
        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let entry = pointer.pointee
            guard
                let address = entry.ifa_addr,
                address.pointee.sa_family == UInt8(AF_LINK),
                let data = entry.ifa_data,
                String(cString: entry.ifa_name).hasPrefix("en")
            else { continue }
            let stats = data.assumingMemoryBound(to: if_data.self).pointee
            received += UInt64(stats.ifi_ibytes)
            sent += UInt64(stats.ifi_obytes)
        }
        return NetworkCounters(received: received, sent: sent)
    }

    // MARK: Battery

    private func battery() -> [Reading] {
        guard
            let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
            let source = sources.first,
            let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
            let capacity = info[kIOPSCurrentCapacityKey] as? Int,
            let max = info[kIOPSMaxCapacityKey] as? Int,
            max > 0
        else { return [] }

        let charging = (info[kIOPSIsChargingKey] as? Bool) ?? false
        var readings = [
            Reading(group: .battery, label: "Charge", value: Format.percent(Double(capacity) / Double(max))),
            Reading(group: .battery, label: "State", value: charging ? "Charging" : "On battery"),
        ]
        if let minutes = info[kIOPSTimeToEmptyKey] as? Int, minutes > 0 {
            readings.append(Reading(group: .battery, label: "Time left", value: Format.duration(TimeInterval(minutes * 60))))
        }
        return readings
    }

    // MARK: System

    private func system() -> [Reading] {
        let process = ProcessInfo.processInfo
        return [
            Reading(group: .system, label: "Uptime", value: Format.duration(process.systemUptime)),
            Reading(group: .system, label: "Thermal state", value: Self.describe(process.thermalState)),
        ]
    }

    static func describe(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "Normal"
        case .fair: return "Warm"
        case .serious: return "Hot"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
}
