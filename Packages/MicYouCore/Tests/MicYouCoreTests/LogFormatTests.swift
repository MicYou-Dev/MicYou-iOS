// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import MicYouCore

@Suite struct LogLines {
    private let formatter = LogFormatter(timeZone: TimeZone(secondsFromGMT: 8 * 3600)!)
    /// 2026/10/11 14:03:22.415 at UTC+08:00
    private let date = Date(timeIntervalSince1970: 1_791_698_602.415)

    @Test func columnsLineUp() {
        #expect(formatter.line(date: date, level: .info, module: "model", message: "Connecting")
            == "2026/10/11 14:03:22.415 [INFO]   model:    Connecting")
        #expect(formatter.line(date: date, level: .notice, module: "activity", message: "Ended")
            == "2026/10/11 14:03:22.415 [NOTICE] activity: Ended")
    }

    @Test func longModulesAreNotCut() {
        #expect(formatter.line(date: date, level: .error, module: "averylongmodule", message: "x")
            == "2026/10/11 14:03:22.415 [ERROR]  averylongmodule: x")
    }

    @Test func continuationLinesIndentUnderTheMessage() {
        let line = formatter.line(date: date, level: .debug, module: "session", message: "first\nsecond")
        let lines = line.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count == 2)
        #expect(lines[1] == String(repeating: " ", count: lines[0].count - "first".count) + "second")
    }

    @Test func utcOffsets() {
        #expect(LogFormatter.utcOffset(of: TimeZone(secondsFromGMT: 8 * 3600)!, at: date) == "UTC+08:00")
        #expect(LogFormatter.utcOffset(of: TimeZone(secondsFromGMT: -(3 * 3600 + 1800))!, at: date) == "UTC-03:30")
        #expect(LogFormatter.utcOffset(of: TimeZone(secondsFromGMT: 0)!, at: date) == "UTC+00:00")
    }
}
