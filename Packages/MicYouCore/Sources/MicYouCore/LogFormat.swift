// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Unified logging levels, as named in exported logs
public enum LogLevel: String, Sendable {
    case debug
    case info
    case notice
    case error
    case fault
}

/// Lines of an exported log, columns padded so they line up:
/// "2026/10/11 14:03:22.415 [INFO]   model:    Connecting to a nearby computer"
public struct LogFormatter {
    /// "[NOTICE]" plus a space
    private static let levelWidth = 9
    /// "activity:" plus a space, longer categories push the message right instead of being cut
    private static let moduleWidth = 10

    private let dates: DateFormatter

    public init(timeZone: TimeZone = .current) {
        dates = DateFormatter()
        dates.locale = Locale(identifier: "en_US_POSIX")
        dates.calendar = Calendar(identifier: .gregorian)
        dates.timeZone = timeZone
        dates.dateFormat = "yyyy/MM/dd HH:mm:ss.SSS"
    }

    public func line(date: Date, level: LogLevel, module: String, message: String) -> String {
        let prefix = dates.string(from: date) + " "
            + Self.padded("[\(level.rawValue.uppercased())]", to: Self.levelWidth)
            + Self.padded("\(module):", to: Self.moduleWidth)
        // Continuation lines start under the message, so every entry still begins with a date
        let indent = "\n" + String(repeating: " ", count: prefix.count)
        return prefix + message.split(separator: "\n", omittingEmptySubsequences: false).joined(separator: indent)
    }

    /// "UTC+08:00", for the header that says which time the dates are in
    public static func utcOffset(of timeZone: TimeZone, at date: Date) -> String {
        let seconds = timeZone.secondsFromGMT(for: date)
        let minutes = abs(seconds) / 60
        return String(format: "UTC%@%02d:%02d", seconds < 0 ? "-" : "+", minutes / 60, minutes % 60)
    }

    private static func padded(_ text: String, to width: Int) -> String {
        text.count >= width ? text + " " : text + String(repeating: " ", count: width - text.count)
    }
}
