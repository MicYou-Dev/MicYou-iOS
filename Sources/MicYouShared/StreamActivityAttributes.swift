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
        /// Input level from 0 to 1, quantized so small changes do not cause updates
        public var level: Double

        public init(phase: Phase, isMuted: Bool, startedAt: Date, detail: String, level: Double = 0) {
            self.phase = phase
            self.isMuted = isMuted
            self.startedAt = startedAt
            self.detail = detail
            self.level = level
        }

        /// Maps dBFS on a -60...0 dB scale to 0...1 in 20 steps
        public static func quantizedLevel(dB: Float) -> Double {
            let fraction = Double(max(0, min(1, (dB + 60) / 60)))
            return (fraction * 20).rounded() / 20
        }
    }

    public var serverName: String

    public init(serverName: String) {
        self.serverName = serverName
    }
}
#endif
