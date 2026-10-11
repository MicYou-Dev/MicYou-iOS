// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import MicYouCore
import OSLog

/// The app's own log entries since launch as a text file
/// iOS keeps logs of the current process only, so a problem has to be exported before the app is closed
/// Reading the store takes a while, call this off the main thread
enum LogExport {
    /// Writes the file with `header`, the Diagnostics.report, at the top
    static func write(header: String) throws -> URL {
        let now = Date.now
        let formatter = LogFormatter()
        let lines: [String]
        do {
            lines = try entries().map {
                formatter.line(date: $0.date, level: level($0.level), module: $0.category, message: $0.composedMessage)
            }
        } catch {
            lines = ["(logs unavailable: \(error.localizedDescription))"]
        }
        let title = "Log since launch, times in \(LogFormatter.utcOffset(of: .current, at: now))"
        let text = ([header, "", title, ""] + (lines.isEmpty ? ["(no entries)"] : lines)).joined(separator: "\n") + "\n"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("MicYou \(fileDate.string(from: now))")
            .appendingPathExtension("txt")
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// The process also holds the logs of every system framework it uses, far more than the app's own
    /// The store filters by subsystem itself when it accepts the predicate, otherwise it is done here
    private static func entries() throws -> [OSLogEntryLog] {
        let store = try OSLogStore(scope: .currentProcessIdentifier)
        let own = { (entries: AnySequence<OSLogEntry>) in
            entries.compactMap { $0 as? OSLogEntryLog }.filter { $0.subsystem == Logger.subsystem }
        }
        do {
            return own(try store.getEntries(matching: NSPredicate(format: "subsystem == %@", Logger.subsystem)))
        } catch {
            return own(try store.getEntries())
        }
    }

    private static func level(_ level: OSLogEntryLog.Level) -> LogLevel {
        switch level {
        case .debug: .debug
        case .info: .info
        case .error: .error
        case .fault: .fault
        // Plain Logger.log and notice both land here
        default: .notice
        }
    }

    private static let fileDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
        return formatter
    }()
}
