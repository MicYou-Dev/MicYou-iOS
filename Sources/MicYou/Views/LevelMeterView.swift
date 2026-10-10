// SPDX-License-Identifier: GPL-3.0-or-later

import MicYouShared
import SwiftUI

struct LevelMeterView: View {
    /// Input level in dBFS, shown on a -60...0 dB scale
    var levelDB: Float
    @State private var ballistics = MeterBallistics()

    var body: some View {
        // Redraws every frame while the meter moves so it glides between the 30 Hz level updates
        TimelineView(.animation(paused: ballistics.isSettled(at: levelDB))) { timeline in
            let shown = ballistics.advance(to: levelDB, at: timeline.date)
            GeometryReader { proxy in
                let fraction = CGFloat(max(0, min(1, (shown + 60) / 60)))
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    // Green up to -18 dB, yellow to -6 dB, then red, revealed from the left
                    LinearGradient(stops: [
                        .init(color: .green, location: 0),
                        .init(color: .green, location: 0.65),
                        .init(color: .yellow, location: 0.75),
                        .init(color: .yellow, location: 0.85),
                        .init(color: .red, location: 0.95),
                    ], startPoint: .leading, endPoint: .trailing)
                    .mask(alignment: .leading) {
                        Capsule().frame(width: proxy.size.width * fraction)
                    }
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel(L10n.Status.inputLevel)
        .accessibilityValue(L10n.Unit.dB(Int(levelDB.rounded())))
    }
}

/// Meter ballistics: quick rise, steady fall in dB per second, like a hardware peak meter
/// A class so per frame updates do not invalidate the view
final class MeterBallistics {
    private var shown: Float = -60
    private var last: Date?
    private let attack: Float = 0.025
    private let fallRate: Float = 36

    func isSettled(at target: Float) -> Bool {
        abs(max(target, -60) - shown) < 0.1
    }

    func advance(to target: Float, at date: Date) -> Float {
        let target = max(target, -60)
        let dt = Float(min(date.timeIntervalSince(last ?? date), 0.1))
        last = date
        if target > shown {
            shown += (target - shown) * (1 - exp(-dt / attack))
        } else {
            shown = max(target, shown - fallRate * dt)
        }
        return shown
    }
}
