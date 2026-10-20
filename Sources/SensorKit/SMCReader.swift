import CSMC
import Foundation

/// Reads temperatures and fan speeds from the System Management Controller.
/// Returns no readings (instead of failing) on Macs where the SMC is not reachable.
public final class SMCReader {
    private var connection: io_connect_t = 0
    private let isOpen: Bool
    private lazy var temperatureKeys: [String] = discoverTemperatureKeys()
    private lazy var fanCount: Int = Int(readNumber("FNum") ?? 0)

    public init() {
        isOpen = smc_open(&connection) == KERN_SUCCESS
    }

    deinit {
        if isOpen { smc_close(connection) }
    }

    public var isAvailable: Bool { isOpen }

    public func readings() -> [Reading] {
        guard isOpen else { return [] }
        return temperatureReadings() + fanReadings()
    }

    // MARK: Temperatures

    private func temperatureReadings() -> [Reading] {
        temperatureKeys.compactMap { key in
            guard let celsius = readNumber(key), SMCDecoder.isPlausibleTemperature(celsius) else { return nil }
            return Reading(
                group: .temperature,
                label: SMCDecoder.temperatureLabel(for: key),
                value: String(format: "%.0f°C", celsius),
                number: celsius,
                isPrimary: SMCDecoder.hasFriendlyLabel(for: key)
            )
        }
    }

    private func discoverTemperatureKeys() -> [String] {
        let total = Int(readNumber("#KEY") ?? 0)
        var keys: [String] = []
        for index in 0..<total {
            var buffer = [CChar](repeating: 0, count: 5)
            guard smc_key_at_index(connection, UInt32(index), &buffer) == KERN_SUCCESS else { continue }
            let key = String(cString: buffer)
            guard key.hasPrefix("T"), let value = readValue(key) else { continue }
            guard value.type == "sp78" || value.type == "flt " else { continue }
            guard let celsius = SMCDecoder.decode(type: value.type, bytes: value.bytes),
                  SMCDecoder.isPlausibleTemperature(celsius)
            else { continue }
            keys.append(key)
        }
        return keys.sorted()
    }

    // MARK: Fans

    private func fanReadings() -> [Reading] {
        (0..<fanCount).flatMap { index -> [Reading] in
            let name = fanCount > 1 ? "Fan \(index + 1)" : "Fan"
            var rows: [Reading] = []
            if let rpm = readNumber("F\(index)Ac") {
                rows.append(Reading(group: .fans, label: name, value: String(format: "%.0f rpm", rpm), number: rpm))
            }
            if let minimum = readNumber("F\(index)Mn"), let maximum = readNumber("F\(index)Mx") {
                rows.append(Reading(
                    group: .fans,
                    label: "\(name) range",
                    value: String(format: "%.0f–%.0f rpm", minimum, maximum)
                ))
            }
            return rows
        }
    }

    // MARK: Raw access

    private func readValue(_ key: String) -> (type: String, bytes: [UInt8])? {
        var value = SMCValue()
        guard smc_read(connection, key, &value) == KERN_SUCCESS else { return nil }
        let type = withUnsafeBytes(of: value.type) { raw in
            String(decoding: raw.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
        let size = min(Int(value.size), 32)
        let bytes = withUnsafeBytes(of: value.bytes) { Array($0.prefix(size)) }
        return (type, bytes)
    }

    private func readNumber(_ key: String) -> Double? {
        guard let value = readValue(key) else { return nil }
        return SMCDecoder.decode(type: value.type, bytes: value.bytes)
    }
}
