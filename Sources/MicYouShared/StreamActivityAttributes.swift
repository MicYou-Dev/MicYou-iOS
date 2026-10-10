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
        /// For example "Opus 64 kbps · Stereo · UDP"
        public var detail: String
        /// Name of the microphone in use, empty when unknown
        public var input: String
        /// SF Symbol for that microphone
        public var inputSymbol: String
        /// Current reconnect attempt and the limit, zero when not reconnecting
        public var attempt: Int
        public var maxAttempts: Int

        public init(phase: Phase, isMuted: Bool, startedAt: Date, detail: String,
                    input: String = "", inputSymbol: String = "mic.fill", attempt: Int = 0, maxAttempts: Int = 0) {
            self.phase = phase
            self.isMuted = isMuted
            self.startedAt = startedAt
            self.detail = detail
            self.input = input
            self.inputSymbol = inputSymbol
            self.attempt = attempt
            self.maxAttempts = maxAttempts
        }
    }

    public var serverName: String

    public init(serverName: String) {
        self.serverName = serverName
    }
}
#endif
