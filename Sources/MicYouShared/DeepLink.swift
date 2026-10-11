// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// URLs handled by the app, used by the Live Activity and Shortcuts
public enum DeepLink: String, CaseIterable, Sendable {
    case connect
    case disconnect
    case toggle
    case mute
    case unmute
    case toggleMute = "toggle-mute"

    public static let scheme = "micyou"

    public var url: URL {
        URL(string: "\(Self.scheme)://\(rawValue)")!
    }

    public init?(url: URL) {
        guard url.scheme?.lowercased() == Self.scheme, let host = url.host()?.lowercased() else { return nil }
        self.init(rawValue: host)
    }
}
