// SPDX-License-Identifier: GPL-3.0-or-later

#if canImport(ActivityKit)
import ActivityKit
import Foundation

/// Shared between the app, which drives the activity, and the widget extension, which renders it
public struct StreamActivityAttributes: ActivityAttributes {
    public enum Phase: String, Codable, Hashable, Sendable {
        case connecting
        case streaming
        case reconnecting
    }

    public struct ContentState: Codable, Hashable, Sendable {
        public var phase: Phase
        public var isMuted: Bool
        /// Start of the current streaming run, drives the timer text
        public var startedAt: Date
        /// For example "Opus 48 kHz"
        public var detail: String

        public init(phase: Phase, isMuted: Bool, startedAt: Date, detail: String) {
            self.phase = phase
            self.isMuted = isMuted
            self.startedAt = startedAt
            self.detail = detail
        }
    }

    public var serverName: String

    public init(serverName: String) {
        self.serverName = serverName
    }
}
#endif
