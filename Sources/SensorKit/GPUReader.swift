import Foundation
import IOKit

/// Reads GPU utilization from the IOKit accelerator registry entries.
enum GPUReader {
    private static let utilizationKeys = ["Device Utilization %", "GPU Activity(%)"]

    /// Highest utilization (0...1) across GPUs, or nil if none report it.
    static func utilization() -> Double? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator)
            == KERN_SUCCESS
        else { return nil }
        defer { IOObjectRelease(iterator) }

        var best: Double?
        var entry = IOIteratorNext(iterator)
        while entry != IO_OBJECT_NULL {
            if let value = utilization(of: entry) {
                best = max(best ?? 0, value)
            }
            IOObjectRelease(entry)
            entry = IOIteratorNext(iterator)
        }
        return best
    }

    private static func utilization(of entry: io_registry_entry_t) -> Double? {
        var properties: Unmanaged<CFMutableDictionary>?
        guard
            IORegistryEntryCreateCFProperties(entry, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
            let dictionary = properties?.takeRetainedValue() as? [String: Any],
            let stats = dictionary["PerformanceStatistics"] as? [String: Any]
        else { return nil }

        for key in utilizationKeys {
            if let percent = (stats[key] as? NSNumber)?.doubleValue {
                return min(max(percent / 100, 0), 1)
            }
        }
        return nil
    }
}
