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
                // The leading and trailing regions only reach the camera, too narrow for a host name,
                // so the top row holds the badge and the timer and everything with text goes below
                DynamicIslandExpandedRegion(.leading) {
                    Badge(state: state, size: 40)
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
                    IslandDetails(serverName: context.attributes.serverName, state: state)
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
                TitleStack(serverName: serverName, subtitle: phaseText(state))
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

/// Compact and minimal presentation
private struct Glyph: View {
    let state: State

    var body: some View {
        Image(systemName: state.symbol)
            .fontWeight(.semibold)
            .foregroundStyle(state.tint)
    }
}

/// Microphone and stream format while live, retry progress otherwise, then the two controls
/// The input level is left out on purpose: every update makes the system crossfade the timer
private struct ControlRow: View {
    let state: State

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                if state.phase == .streaming, !state.input.isEmpty {
                    Label(state.input, systemImage: state.inputSymbol)
                        .font(.subheadline.weight(.medium))
                } else if state.phase != .streaming {
                    Text(progressText)
                        .font(.subheadline.weight(.medium))
                }
                if !state.detail.isEmpty {
                    Text(state.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, alignment: .leading)
            ActionLinks(state: state)
        }
    }

    private var progressText: String {
        if state.phase == .reconnecting, state.attempt > 0 {
            return L10n.Status.reconnectingAttempt(state.attempt, of: state.maxAttempts)
        }
        return phaseText(state)
    }
}

/// Bottom of the expanded island, full width so long host names fit
/// Status and microphone share a line, the badge color already tells the phase at a glance
private struct IslandDetails: View {
    let serverName: String
    let state: State

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(serverName)
                    .font(.headline)
                Text(status)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !state.detail.isEmpty {
                    Text(state.detail)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, alignment: .leading)
            ActionLinks(state: state)
        }
    }

    /// For example "Streaming · iPhone Microphone" or "Reconnecting (2/6)…"
    private var status: String {
        if state.phase == .reconnecting, state.attempt > 0 {
            return L10n.Status.reconnectingAttempt(state.attempt, of: state.maxAttempts)
        }
        return L10n.Common.joined([phaseText(state), state.phase == .streaming ? state.input : ""])
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
        // The connection is still up while the microphone is interrupted, so the clock keeps running
        if state.phase == .streaming || state.phase == .interrupted {
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
        case .interrupted: .yellow
        }
    }

    var symbol: String {
        switch phase {
        case .streaming: isMuted ? "mic.slash.fill" : "mic.fill"
        case .connecting, .reconnecting: "antenna.radiowaves.left.and.right"
        case .interrupted: "pause.fill"
        }
    }
}

private func phaseText(_ state: State) -> String {
    switch state.phase {
    case .connecting: L10n.Status.connecting
    case .reconnecting: L10n.Status.reconnecting
    case .streaming: state.isMuted ? L10n.Status.muted : L10n.Status.streaming
    case .interrupted: L10n.Status.interrupted
    }
}
