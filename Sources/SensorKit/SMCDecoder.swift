import Foundation

/// Pure decoding helpers for values returned by the System Management Controller.
public enum SMCDecoder {
    private static let knownTemperatureLabels: [String: String] = [
        "TC0P": "CPU proximity",
        "TC0D": "CPU die",
        "TC0E": "CPU",
        "TC0F": "CPU",
        "TCXC": "CPU PECI",
        "TG0P": "GPU proximity",
        "TG0D": "GPU die",
        "TA0P": "Ambient",
        "TB0T": "Battery",
        "Th0H": "Heatpipe",
        "TM0P": "Memory proximity",
        "Ts0P": "Palm rest",
        "TPCD": "Platform controller",
    ]

    public static func decode(type: String, bytes: [UInt8]) -> Double? {
        switch type {
        case "sp78":
            guard bytes.count >= 2 else { return nil }
            let raw = Int16(bitPattern: UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
            return Double(raw) / 256
        case "fpe2":
            guard bytes.count >= 2 else { return nil }
            return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1])) / 4
        case "flt ":
            guard bytes.count >= 4 else { return nil }
            let bits = UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24
            return Double(Float(bitPattern: bits))
        case "ui8 ":
            guard let first = bytes.first else { return nil }
            return Double(first)
        case "ui16":
            guard bytes.count >= 2 else { return nil }
            return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
        case "ui32":
            guard bytes.count >= 4 else { return nil }
            let value = bytes.prefix(4).reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
            return Double(value)
        default:
            return nil
        }
    }

    /// Unplugged or unsupported probes report 0 or absurd values; hide those.
    public static func isPlausibleTemperature(_ celsius: Double) -> Bool {
        celsius > 10 && celsius < 130
    }

    public static func hasFriendlyLabel(for key: String) -> Bool {
        knownTemperatureLabels[key] != nil
    }

    public static func temperatureLabel(for key: String) -> String {
        knownTemperatureLabels[key] ?? key
    }
}
