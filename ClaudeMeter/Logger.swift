import Foundation
import AppKit

// File-based logger. Writes to ~/Library/Logs/ClaudeMeter/claudemeter.log.
// Rotates when the file exceeds maxBytes — keeps one archive (.1).
// Never logs token values or API response bodies; only category + outcome + timing.

enum LogLevel: String {
    case info = "INFO"
    case warn = "WARN"
    case error = "ERROR"
}

@MainActor
final class Logger {
    static let shared = Logger()

    private static let maxBytes: Int = 512 * 1024 // 512 KB

    private let logURL: URL
    private let archiveURL: URL
    private let formatter: DateFormatter
    private let appVersion: String
    private let osVersion: String

    private init() {
        let dir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("ClaudeMeter", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.logURL = dir.appendingPathComponent("claudemeter.log")
        self.archiveURL = dir.appendingPathComponent("claudemeter.log.1")

        self.formatter = DateFormatter()
        self.formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

        let info = Bundle.main.infoDictionary
        self.appVersion = (info?["CFBundleShortVersionString"] as? String) ?? "?"
        let v = ProcessInfo.processInfo.operatingSystemVersion
        self.osVersion = "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }

    func info(_ category: String, _ message: String) { write(.info, category, message) }
    func warn(_ category: String, _ message: String) { write(.warn, category, message) }
    func error(_ category: String, _ message: String) { write(.error, category, message) }

    private func write(_ level: LogLevel, _ category: String, _ message: String) {
        let line = "\(formatter.string(from: Date())) [\(level.rawValue)] [\(category)] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }

        rotateIfNeeded()

        if let handle = try? FileHandle(forWritingTo: logURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: logURL)
        }
    }

    private func rotateIfNeeded() {
        guard
            let attrs = try? FileManager.default.attributesOfItem(atPath: logURL.path),
            let size = attrs[.size] as? Int,
            size > Self.maxBytes
        else { return }
        try? FileManager.default.removeItem(at: archiveURL)
        try? FileManager.default.moveItem(at: logURL, to: archiveURL)
    }

    var logFileURL: URL { logURL }

    func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([logURL])
    }

    // Builds a redacted diagnostic blob: env info + last N lines from both
    // current log and (if present) the archive.
    func diagnosticBlob(lineLimit: Int = 200) -> String {
        let header = """
        ClaudeMeter Diagnostic
        =====================
        App version : \(appVersion)
        macOS       : \(osVersion)
        Generated   : \(formatter.string(from: Date()))

        """

        let current = (try? String(contentsOf: logURL, encoding: .utf8)) ?? ""
        let archived = (try? String(contentsOf: archiveURL, encoding: .utf8)) ?? ""
        let combined = archived + current
        let lines = combined.split(separator: "\n", omittingEmptySubsequences: false)
        let tail = lines.suffix(lineLimit).joined(separator: "\n")
        return header + tail
    }
}

// Convenience accessor — keeps call sites short. Logger is MainActor-isolated;
// most calls happen from UsageService which is also MainActor, so no hop needed.
@MainActor
func log(_ level: LogLevel = .info, _ category: String, _ message: String) {
    switch level {
    case .info:  Logger.shared.info(category, message)
    case .warn:  Logger.shared.warn(category, message)
    case .error: Logger.shared.error(category, message)
    }
}
