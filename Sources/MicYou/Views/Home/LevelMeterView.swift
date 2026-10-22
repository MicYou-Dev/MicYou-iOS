// SPDX-License-Identifier: GPL-3.0-or-later

import MicYouCore
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
        // The meter bottoms out at its floor, silence would otherwise read as -160
        .accessibilityValue(L10n.Unit.dB(Int(max(levelDB, MeterBallistics.floor).rounded())))
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
