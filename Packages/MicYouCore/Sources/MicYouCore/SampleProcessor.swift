// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Keeps gained samples below full scale: instant attack, about 50 ms release
public struct PeakLimiter: Sendable {
    public static let ceiling: Float = 0.95
    private var reduction: Float = 1
    private let release: Float = 0.0004

    public init() {}

    public mutating func process(_ x: Float) -> Float {
        // Release first, so a sample right after a loud one cannot slip past the ceiling
        reduction += (1 - reduction) * release
        if abs(x) * reduction > Self.ceiling {
            reduction = Self.ceiling / abs(x)
        }
        return x * reduction
    }
}

/// Turns converted float samples into the interleaved little-endian Int16 the desktop expects
/// Not thread safe, the limiter carries state from one block to the next
public struct SampleProcessor: Sendable {
    /// Level reported for silence, in dBFS
    public static let silence: Float = -160

    private var limiter = PeakLimiter()

    public init() {}

    /// Applies the linear gain and the limiter, writing each sample twice when `duplicate` is set,
    /// which turns mono hardware into a stereo stream. Returns the PCM and the RMS level in dBFS
    public mutating func process(_ samples: UnsafeBufferPointer<Float>, gain: Float, duplicate: Bool) -> (pcm: Data, levelDB: Float) {
        let copies = duplicate ? 2 : 1
        var data = Data(count: samples.count * 2 * copies)
        var sumSquares: Float = 0
        data.withUnsafeMutableBytes { raw in
            let dst = raw.bindMemory(to: Int16.self)
            for i in 0..<samples.count {
                let y = limiter.process(samples[i] * gain)
                sumSquares += y * y
                let pcm = Int16(max(-32768, min(32767, (y * 32767).rounded()))).littleEndian
                for c in 0..<copies { dst[i * copies + c] = pcm }
            }
        }
        guard !samples.isEmpty else { return (data, Self.silence) }
        return (data, Self.dBFS(rms: (sumSquares / Float(samples.count)).squareRoot()))
    }

    public static func dBFS(rms: Float) -> Float {
        rms > 0 ? max(silence, 20 * log10(rms)) : silence
    }

    /// Linear factor for a gain in dB
    public static func linearGain(dB: Double) -> Float {
        Float(pow(10, dB / 20))
    }
}
