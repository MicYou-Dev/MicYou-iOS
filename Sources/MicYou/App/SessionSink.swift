// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Hands PCM from the capture thread to the current session and throttles level updates
/// The session is swapped on reconnect while capture keeps running
final class SessionSink: @unchecked Sendable {
    private let lock = NSLock()
    private var session: StreamSession?
    private var peak: Float = -160
    private var lastPost: TimeInterval = 0
    private let postInterval: TimeInterval = 1.0 / 30

    func set(_ session: StreamSession?) {
        lock.withLock { self.session = session }
    }

    /// Returns the loudest block level about 30 times per second, the meter view smooths it per frame
    func push(_ pcm: Data, level: Float) -> Float? {
        let (session, value): (StreamSession?, Float?) = lock.withLock {
            peak = max(peak, level)
            let now = ProcessInfo.processInfo.systemUptime
            var value: Float?
            if now - lastPost >= postInterval {
                lastPost = now
                value = peak
                peak = -160
            }
            return (self.session, value)
        }
        session?.push(pcm)
        return value
    }
}
