// SPDX-License-Identifier: GPL-3.0-or-later

/// When a dropped stream is retried and how long to wait before each attempt
public struct ReconnectPolicy: Sendable {
    public static let standard = ReconnectPolicy(maxAttempts: 6, maxDelay: 15)

    public let maxAttempts: Int
    /// Seconds, the doubling delay stops growing here
    public let maxDelay: Double

    public init(maxAttempts: Int, maxDelay: Double) {
        self.maxAttempts = maxAttempts
        self.maxDelay = maxDelay
    }

    /// Seconds before an attempt, counted from 1: 1, 2, 4, 8, then capped
    public func delay(beforeAttempt attempt: Int) -> Double {
        min(Double(1 << max(0, min(attempt - 1, 30))), maxDelay)
    }

    /// Only a stream that worked is retried, and only for errors that may go away by themselves
    public func shouldRetry(attempt: Int, enabled: Bool, hasStreamed: Bool, errorIsTransient: Bool) -> Bool {
        enabled && hasStreamed && errorIsTransient && attempt <= maxAttempts
    }
}
