// SPDX-License-Identifier: GPL-3.0-or-later

import MicYouShared
import SwiftUI

/// Segmented input meter like a hardware LED bar
struct LevelMeterView: View {
    /// Input level in dBFS, shown on a -60...0 dB scale
    var levelDB: Float
    var segments = 32
    @State private var ballistics = MeterBallistics()
    /// Paused once the bar and the peak have come to rest, a silent or muted input then costs nothing
    @State private var isIdle = true

    var body: some View {
        // Redraws while the meter moves so it glides between the 30 Hz level updates
        // 60 Hz is plenty for 32 segments, ProMotion would otherwise draw it twice as often for nothing
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: isIdle)) { timeline in
            let reading = ballistics.advance(to: levelDB, at: timeline.date)
            Canvas { context, size in
                let gap: CGFloat = 3
                let width = (size.width - gap * CGFloat(segments - 1)) / CGFloat(segments)
                let lit = segmentCount(for: reading.level)
                // The held peak stays lit as one segment above the bar
                let peak = segmentCount(for: reading.peak) - 1
                for index in 0..<segments {
                    let rect = CGRect(x: CGFloat(index) * (width + gap), y: 0, width: width, height: size.height)
                    let color = index < lit || (index == peak && peak >= lit) ? zoneColor(index) : Color(.tertiarySystemFill)
                    context.fill(Path(roundedRect: rect, cornerRadius: min(3, width / 2)), with: .color(color))
                }
            }
            .onChange(of: reading.isSettled) { _, settled in
                if settled { isIdle = true }
            }
        }
        .onChange(of: levelDB, initial: true) { _, level in
            if !ballistics.isSettled(at: level) { isIdle = false }
        }
        .accessibilityElement()
        .accessibilityLabel(L10n.Status.inputLevel)
        // The meter bottoms out at -60 dB, silence would otherwise read as -160
        .accessibilityValue(L10n.Unit.dB(Int(max(levelDB, -60).rounded())))
    }

    private func segmentCount(for level: Float) -> Int {
        let fraction = CGFloat(max(0, min(1, (level + 60) / 60)))
        return Int((fraction * CGFloat(segments)).rounded())
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

/// Meter ballistics: quick rise, steady fall in dB per second, and a peak that holds for a moment before it falls,
/// like a hardware peak meter. A class so per frame updates do not invalidate the view
final class MeterBallistics {
    struct Reading {
        var level: Float
        var peak: Float
        var isSettled: Bool
    }

    private static let floor: Float = -60
    private var shown = floor
    private var peak = floor
    private var peakAge: TimeInterval = 0
    private var last: Date?
    private let attack: Float = 0.025
    private let fallRate: Float = 36
    private let peakHold: TimeInterval = 1
    private let peakFallRate: Float = 18

    func isSettled(at target: Float) -> Bool {
        abs(max(target, Self.floor) - shown) < 0.1 && peak <= shown + 0.1
    }

    func advance(to target: Float, at date: Date) -> Reading {
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
