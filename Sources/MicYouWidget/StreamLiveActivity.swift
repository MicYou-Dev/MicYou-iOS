// SPDX-License-Identifier: GPL-3.0-or-later

import ActivityKit
import MicYouShared
import SwiftUI
import WidgetKit

private typealias State = StreamActivityAttributes.ContentState

struct StreamLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StreamActivityAttributes.self) { context in
            LockScreenView(serverName: context.attributes.serverName, state: context.state)
                .padding(16)
                .activityBackgroundTint(nil)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading, priority: 1) {
                    HStack(spacing: 10) {
                        Badge(state: state, size: 40)
                        TitleStack(serverName: context.attributes.serverName, subtitle: phaseText(state))
                    }
                    // Keep the top row clear of the island's rounded corners
                    .padding(.leading, 6)
                    .padding(.top, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ElapsedText(state: state)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(state.tint)
                        .frame(maxWidth: 88, maxHeight: 40, alignment: .trailing)
                        .padding(.trailing, 6)
                        .padding(.top, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ControlRow(state: state)
                        .padding(.horizontal, 6)
                        .padding(.top, 6)
                }
            } compactLeading: {
                Glyph(state: state)
            } compactTrailing: {
                ElapsedText(state: state)
                    .foregroundStyle(state.tint)
                    .frame(maxWidth: 48)
            } minimal: {
                Glyph(state: state)
            }
            .keylineTint(state.tint)
        }
    }
}

// MARK: Lock Screen

private struct LockScreenView: View {
    let serverName: String
    let state: State

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Badge(state: state, size: 44)
                TitleStack(serverName: serverName, subtitle: L10n.Common.joined([phaseText(state), state.detail]))
                    .layoutPriority(1)
                Spacer(minLength: 8)
                ElapsedText(state: state)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(state.tint)
            }
            ControlRow(state: state)
        }
    }
}

// MARK: Building blocks

private struct TitleStack: View {
    let serverName: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(serverName)
                .font(.headline)
                .lineLimit(1)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

/// Solid tinted circle with the status glyph, like the avatar in a call
private struct Badge: View {
    let state: State
    let size: CGFloat

    var body: some View {
        Image(systemName: state.symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(state.tint.gradient, in: Circle())
    }
}

/// Compact and minimal presentation: a small meter while live, otherwise the status symbol
private struct Glyph: View {
    let state: State

    var body: some View {
        if state.phase == .streaming, !state.isMuted {
            MiniMeter(level: state.level, tint: state.tint)
        } else {
            Image(systemName: state.symbol)
                .fontWeight(.semibold)
                .foregroundStyle(state.tint)
        }
    }
}

/// Five bars shaped like a waveform, lit from the left as the level rises
private struct MiniMeter: View {
    let level: Double
    let tint: Color
    private let heights: [CGFloat] = [0.45, 0.75, 1, 0.75, 0.45]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(heights.indices, id: \.self) { index in
                Capsule()
                    .fill(lit(index) ? AnyShapeStyle(tint) : AnyShapeStyle(.white.opacity(0.3)))
                    .frame(width: 3, height: 14 * heights[index])
            }
        }
        .frame(height: 14)
        .accessibilityLabel(L10n.Status.inputLevel)
    }

    private func lit(_ index: Int) -> Bool {
        // The first bar always shows so the meter reads as live even in silence
        index == 0 || level >= Double(index) / Double(heights.count)
    }
}

/// Segmented level meter while streaming, status text otherwise, then the two controls
private struct ControlRow: View {
    let state: State

    var body: some View {
        HStack(spacing: 12) {
            if state.phase == .streaming {
                SegmentedMeter(level: state.level, tint: state.tint)
            } else {
                Text(phaseText(state))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ActionLinks(state: state)
        }
    }
}

/// Input level in discrete segments, updated about once a second by the app
private struct SegmentedMeter: View {
    let level: Double
    let tint: Color
    private let segments = 20

    var body: some View {
        let lit = Int((level * Double(segments)).rounded())
        HStack(spacing: 3) {
            ForEach(0..<segments, id: \.self) { index in
                Capsule()
                    .fill(index < lit ? AnyShapeStyle(tint) : AnyShapeStyle(.quaternary))
            }
        }
        .frame(height: 16)
        .frame(maxWidth: .infinity)
        .accessibilityElement()
        .accessibilityLabel(L10n.Status.inputLevel)
        .accessibilityValue(Text(level, format: .percent.precision(.fractionLength(0))))
    }
}

/// Links open the app through its URL scheme, App Intent buttons need metadata xtool cannot generate
private struct ActionLinks: View {
    let state: State

    var body: some View {
        HStack(spacing: 10) {
            // Works like the mute toggle in the Phone app: inverted while muted
            Link(destination: DeepLink.toggleMute.url) {
                Image(systemName: "mic.slash.fill")
                    .frame(width: 40, height: 40)
                    .foregroundStyle(state.isMuted ? AnyShapeStyle(.background) : AnyShapeStyle(.primary))
                    .background(state.isMuted ? AnyShapeStyle(.primary) : AnyShapeStyle(.quaternary), in: Circle())
            }
            .accessibilityLabel(state.isMuted ? L10n.Common.unmute : L10n.Common.mute)
            Link(destination: DeepLink.disconnect.url) {
                Image(systemName: "xmark")
                    .frame(width: 40, height: 40)
                    .foregroundStyle(.white)
                    .background(.red, in: Circle())
            }
            .accessibilityLabel(L10n.Common.disconnect)
        }
        .font(.body.weight(.semibold))
    }
}

private struct ElapsedText: View {
    let state: State

    var body: some View {
        if state.phase == .streaming {
            Text(timerInterval: state.startedAt...Date.distantFuture, countsDown: false)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        } else {
            Text(L10n.Status.waiting)
        }
    }
}

private extension StreamActivityAttributes.ContentState {
    var tint: Color {
        switch phase {
        case .streaming: isMuted ? .orange : .green
        case .connecting, .reconnecting: .blue
        }
    }

    var symbol: String {
        switch phase {
        case .streaming: isMuted ? "mic.slash.fill" : "mic.fill"
        case .connecting, .reconnecting: "antenna.radiowaves.left.and.right"
        }
    }
}

private func phaseText(_ state: State) -> String {
    switch state.phase {
    case .connecting: L10n.Status.connecting
    case .reconnecting: L10n.Status.reconnecting
    case .streaming: state.isMuted ? L10n.Status.muted : L10n.Status.streaming
    }
}
