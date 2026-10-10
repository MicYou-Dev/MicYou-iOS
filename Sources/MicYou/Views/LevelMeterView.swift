// SPDX-License-Identifier: GPL-3.0-or-later

import MicYouShared
import SwiftUI

/// Segmented input meter like a hardware LED bar
struct LevelMeterView: View {
    /// Input level in dBFS, shown on a -60...0 dB scale
    var levelDB: Float
    var segments = 32
    @State private var ballistics = MeterBallistics()

    var body: some View {
        // Redraws every frame while the meter moves so it glides between the 30 Hz level updates
        TimelineView(.animation(paused: ballistics.isSettled(at: levelDB))) { timeline in
            let shown = ballistics.advance(to: levelDB, at: timeline.date)
            Canvas { context, size in
                let gap: CGFloat = 3
                let width = (size.width - gap * CGFloat(segments - 1)) / CGFloat(segments)
                let fraction = CGFloat(max(0, min(1, (shown + 60) / 60)))
                let lit = Int((fraction * CGFloat(segments)).rounded())
                for index in 0..<segments {
                    let rect = CGRect(x: CGFloat(index) * (width + gap), y: 0, width: width, height: size.height)
                    let color = index < lit ? zoneColor(index) : Color(.tertiarySystemFill)
                    context.fill(Path(roundedRect: rect, cornerRadius: min(3, width / 2)), with: .color(color))
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel(L10n.Status.inputLevel)
        .accessibilityValue(L10n.Unit.dB(Int(levelDB.rounded())))
    }

    /// Green up to -18 dB, yellow to -6 dB, then red, judged by the top of each segment
    private func zoneColor(_ index: Int) -> Color {
        let top = Float(index + 1) / Float(segments) * 60 - 60
        return top <= -18 ? .green : top <= -6 ? .yellow : .red
    }
}

/// dB marks under the meter at the zone boundaries
struct MeterScale: View {
    private static let marks: [Float] = [-60, -18, -6, 0]

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                ForEach(Self.marks, id: \.self) { mark in
                    let fraction = CGFloat((mark + 60) / 60)
                    Text(mark == 0 ? L10n.Unit.dB(0) : String(Int(mark)))
                        // Pins the first mark to the leading edge and the last to the trailing edge
                        .alignmentGuide(.leading) { $0.width * fraction - width * fraction }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.caption2)
        .monospacedDigit()
        .foregroundStyle(.tertiary)
        .frame(height: 14)
        .accessibilityHidden(true)
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
