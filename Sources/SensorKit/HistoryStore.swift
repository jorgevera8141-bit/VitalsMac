import Foundation

/// Saves history points as one JSON object per line. Corrupt lines are skipped on load.
public struct HistoryStore {
    /// How long points are kept.
    public static let retention: TimeInterval = 7 * 24 * 3_600

    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public static var defaultFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("VitalsMac", isDirectory: true).appendingPathComponent("history.jsonl")
    }

    /// Points at or after `cutoff`, oldest first.
    public func load(since cutoff: Date) -> [HistoryPoint] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = Self.makeDecoder()
        return data.split(separator: UInt8(ascii: "\n"))
            .compactMap { try? decoder.decode(HistoryPoint.self, from: Data($0)) }
            .filter { $0.time >= cutoff }
            .sorted { $0.time < $1.time }
    }

    public func append(_ point: HistoryPoint) throws {
        try createDirectory()
        let line = try Self.makeEncoder().encode(point) + Data("\n".utf8)
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            try line.write(to: fileURL)
            return
        }
        let handle = try FileHandle(forWritingTo: fileURL)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: line)
    }

    /// Replaces the file with exactly `points` (used to drop expired or corrupt lines).
    public func rewrite(_ points: [HistoryPoint]) throws {
        try createDirectory()
        let encoder = Self.makeEncoder()
        let data = try points.reduce(into: Data()) { result, point in
            result.append(try encoder.encode(point))
            result.append(Data("\n".utf8))
        }
        try data.write(to: fileURL, options: .atomic)
    }

    private func createDirectory() throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }
}
