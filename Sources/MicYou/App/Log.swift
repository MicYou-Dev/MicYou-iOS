// SPDX-License-Identifier: GPL-3.0-or-later

import os

extension Logger {
    /// All app logs share one subsystem, filter by category in Console or idevicesyslog
    static func micyou(_ category: String) -> Logger {
        Logger(subsystem: "com.chouchiu.micyou", category: category)
    }
}
