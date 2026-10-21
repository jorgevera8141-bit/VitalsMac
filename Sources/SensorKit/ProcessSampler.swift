import Foundation

/// Lists running processes by asking `ps`, which can see every process (library calls only see your own).
public enum ProcessSampler {
    /// All processes, or an empty list if `ps` could not run.
    public static func sample() -> [ProcessUsage] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-Aceo", "pid=,pcpu=,rss=,comm="]
        // The C locale keeps decimals as "12.3" regardless of the user's region settings.
        process.environment = ["LC_ALL": "C"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            NSLog("Vitals: could not run ps: \(error)")
            return []
        }
        // Read before waiting so a full pipe cannot block ps.
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return ProcessListParser.parse(String(decoding: data, as: UTF8.self))
    }
}
