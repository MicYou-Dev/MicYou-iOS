// SPDX-License-Identifier: GPL-3.0-or-later

import MicYouShared
import SwiftUI

/// A black screen over the session, the display stays on but an OLED panel draws almost nothing
/// Starts centered and drifts a little every minute so nothing burns in, a tap anywhere brings the app back
struct DimOverlay: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dimmedAt = Date.now

    /// Offsets cycled through once a minute, small enough that the clock still reads as centered
    private static let drift: [CGSize] = [
        .zero, CGSize(width: -16, height: -40), CGSize(width: 18, height: 32),
        CGSize(width: -10, height: 56), CGSize(width: 14, height: -60), CGSize(width: -20, height: 12),
    ]
    /// How long the wake hint stays before it fades
    private static let hintDuration: TimeInterval = 4

    var body: some View {
        TimelineView(.periodic(from: dimmedAt, by: 1)) { context in
            let elapsed = context.date.timeIntervalSince(dimmedAt)
            let step = Int(elapsed / 60)
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(model.statusTint.opacity(0.7))
                        .frame(width: 6, height: 6)
                    Text(model.statusTitle)
                }
                .font(.footnote.weight(.medium))
                Text(model.streamingSince.map { ElapsedTime.elapsed(from: $0, to: context.date) } ?? L10n.Status.waiting)
                    .font(.system(size: 64, weight: .light))
                    .monospacedDigit()
                // Only needed at first, then it would just be more lit pixels
                Text(L10n.Dim.wake)
                    .font(.caption)
                    .opacity(elapsed < Self.hintDuration ? 1 : 0)
                    .animation(.easeOut(duration: 1), value: elapsed < Self.hintDuration)
                    // Read out as the hint of the whole screen instead
                    .accessibilityHidden(true)
            }
            .foregroundStyle(.white.opacity(0.3))
            .offset(Self.drift[step % Self.drift.count])
            .animation(reduceMotion ? nil : .easeInOut(duration: 2), value: step)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
        .ignoresSafeArea()
        .contentShape(.rect)
        .onTapGesture { model.setDimmed(false) }
        // Lets touches through while it fades out, a quick tap on the dim button right after waking would land here
        .allowsHitTesting(model.isDimmed)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(L10n.Dim.wake)
        .accessibilityAction { model.setDimmed(false) }
    }
}
