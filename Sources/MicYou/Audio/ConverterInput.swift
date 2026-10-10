// SPDX-License-Identifier: GPL-3.0-or-later

@preconcurrency import AVFoundation
import os

extension AVAudioConverter {
    /// Converts one input buffer: the input block hands `input` over once and then reports that
    /// no more data is available for now, so the converter keeps any remainder for the next call
    func convert(to output: AVAudioBuffer, feeding input: AVAudioBuffer, error: NSErrorPointer) -> AVAudioConverterOutputStatus {
        // The converter calls the block synchronously on this thread, but SDKs before iOS 27 import
        // it as an escaping @Sendable closure, a lock keeps the one-shot flag correct under both
        let supplied = OSAllocatedUnfairLock(initialState: false)
        return convert(to: output, error: error) { _, status in
            let first = supplied.withLock { done in
                defer { done = true }
                return !done
            }
            status.pointee = first ? .haveData : .noDataNow
            return first ? input : nil
        }
    }
}
