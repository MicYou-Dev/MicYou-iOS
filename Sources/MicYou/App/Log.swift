// SPDX-License-Identifier: GPL-3.0-or-later

import os

extension Logger {
    /// All app logs share one subsystem, filter by category in Console or idevicesyslog
    static let subsystem = "com.chouchiu.micyou"

    static func micyou(_ category: String) -> Logger {
        Logger(subsystem: subsystem, category: category)
    }
}
