// SPDX-License-Identifier: GPL-3.0-or-later

/// Keeps gained samples below full scale: instant attack, about 50 ms release
struct PeakLimiter {
    private var reduction: Float = 1
    private let ceiling: Float = 0.95
    private let release: Float = 0.0004

    mutating func process(_ x: Float) -> Float {
        let peak = abs(x) * reduction
        if peak > ceiling {
            reduction = ceiling / abs(x)
        } else {
            reduction += (1 - reduction) * release
        }
        return x * reduction
    }
}
