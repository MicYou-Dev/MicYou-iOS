// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Meter ballistics: quick rise, steady fall in dB per second, and a peak that holds for a moment before it falls,
/// like a hardware peak meter. A class so per frame updates do not invalidate the view that owns it
public final class MeterBallistics {
    public struct Reading: Equatable {
        public var level: Float
        public var peak: Float
        public var isSettled: Bool
    }

    public static let floor: Float = -60
    private var shown = floor
    private var peak = floor
    private var peakAge: TimeInterval = 0
    private var last: Date?
    private let attack: Float = 0.025
    private let fallRate: Float = 36
    private let peakHold: TimeInterval = 1
    private let peakFallRate: Float = 18

    public init() {}

    public func isSettled(at target: Float) -> Bool {
        abs(max(target, Self.floor) - shown) < 0.1 && peak <= shown + 0.1
    }

    public func advance(to target: Float, at date: Date) -> Reading {
        let target = max(target, Self.floor)
        let elapsed = min(date.timeIntervalSince(last ?? date), 0.1)
        let dt = Float(elapsed)
        last = date
        if target > shown {
            shown += (target - shown) * (1 - exp(-dt / attack))
        } else {
            shown = max(target, shown - fallRate * dt)
        }
        if shown >= peak {
            peak = shown
            peakAge = 0
        } else {
            peakAge += elapsed
            if peakAge > peakHold { peak = max(shown, peak - peakFallRate * dt) }
        }
        let settled = isSettled(at: target)
        if settled {
            shown = target
            peak = target
        }
        return Reading(level: shown, peak: peak, isSettled: settled)
    }
}
