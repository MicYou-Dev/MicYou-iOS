// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Hands PCM from the capture thread to the current session and throttles level updates
/// The session is swapped on reconnect while capture keeps running
final class SessionSink: @unchecked Sendable {
    private let lock = NSLock()
    private var session: StreamSession?
    private var peak: Float = -160
    private var limited = false
    private var lastPost: TimeInterval = 0
    private let postInterval: TimeInterval = 1.0 / 30

    func set(_ session: StreamSession?) {
        lock.withLock { self.session = session }
    }

    /// Returns the loudest block level about 30 times per second, the meter view smooths it per frame,
    /// with whether any block since the last one was limited
    func push(_ pcm: Data, level: Float, limited: Bool) -> (level: Float, limited: Bool)? {
        let (session, value): (StreamSession?, (level: Float, limited: Bool)?) = lock.withLock {
            peak = max(peak, level)
            self.limited = self.limited || limited
            let now = ProcessInfo.processInfo.systemUptime
            var value: (level: Float, limited: Bool)?
            if now - lastPost >= postInterval {
                lastPost = now
                value = (peak, self.limited)
                peak = -160
                self.limited = false
            }
            return (self.session, value)
        }
        session?.push(pcm)
        return value
    }
}
