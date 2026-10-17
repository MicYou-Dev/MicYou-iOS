// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Suggests another input gain from the levels of a running stream: lower when the limiter keeps
/// catching peaks, higher when even the loudest moments stay quiet
/// Fed with the meter updates, about 30 a second, each carrying the loudest block level since the last
public struct GainAdvisor: Sendable {
    public enum Advice: Equatable, Sendable {
        case lower
        case raise
    }

    /// Updates with limiting within `clipWindow` seconds that call for less gain, a few frames of a cough do not
    static let clipCount = 6
    static let clipWindow: TimeInterval = 3
    /// Seconds the suggestion to lower stays after the last limited update, so it does not flicker between phrases
    static let clipHold: TimeInterval = 5
    /// Seconds whose loudest level decides whether the input is quiet
    static let quietWindow: TimeInterval = 10
    /// A loudest level in this range is speech too far away or too soft, below it is only room noise or silence
    static let quietRange: ClosedRange<Float> = -48 ... -38

    private var clips: [TimeInterval] = []
    private var lastClip: TimeInterval?
    private var windowStart: TimeInterval?
    private var windowPeak = -Float.infinity
    private var isQuiet = false
    private var isLowering = false

    public init() {}

    public mutating func record(levelDB: Float, limited: Bool, at time: TimeInterval) -> Advice? {
        if limited {
            clips.append(time)
            lastClip = time
        }
        clips.removeAll { time - $0 > Self.clipWindow }

        if let start = windowStart {
            windowPeak = max(windowPeak, levelDB)
            if time - start >= Self.quietWindow {
                isQuiet = Self.quietRange.contains(windowPeak)
                windowStart = time
                windowPeak = levelDB
            }
        } else {
            windowStart = time
            windowPeak = levelDB
        }

        let holding = isLowering && lastClip.map { time - $0 < Self.clipHold } == true
        isLowering = clips.count >= Self.clipCount || holding
        if isLowering { return .lower }
        return isQuiet ? .raise : nil
    }

    /// For a new gain or a pause in the audio, which make what was measured so far meaningless
    public mutating func reset() {
        self = GainAdvisor()
    }
}
