// SPDX-License-Identifier: GPL-3.0-or-later

import ActivityKit
import MicYouShared
import SwiftUI
import WidgetKit

struct StreamLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StreamActivityAttributes.self) { context in
            LockScreenView(context: context)
                .padding()
                .activityBackgroundTint(nil)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.attributes.serverName).lineLimit(1)
                    } icon: {
                        StatusIcon(state: state)
                    }
                    .font(.headline)
                    // Keep the top row clear of the island's rounded corners
                    .padding(.leading, 8)
                    .padding(.top, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ElapsedText(state: state)
                        .font(.headline)
                        .frame(maxWidth: 80, alignment: .trailing)
                        .padding(.trailing, 8)
                        .padding(.top, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(state.detail.isEmpty ? phaseText(state) : state.detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        ActionLinks(state: state)
                    }
                }
            } compactLeading: {
                StatusIcon(state: state)
            } compactTrailing: {
                ElapsedText(state: state)
                    .frame(maxWidth: 48)
            } minimal: {
                StatusIcon(state: state)
            }
            .keylineTint(state.tint)
        }
    }
}

private struct LockScreenView: View {
    let context: ActivityViewContext<StreamActivityAttributes>

    var body: some View {
        let state = context.state
        HStack(spacing: 12) {
            StatusIcon(state: state)
                .font(.title3)
                .frame(width: 44, height: 44)
                .background(state.tint.opacity(0.18), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.serverName)
                    .font(.headline)
                    .lineLimit(1)
                Text(L10n.Common.joined([phaseText(state), state.detail]))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .layoutPriority(1)
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                ElapsedText(state: state)
                    .font(.headline)
                ActionLinks(state: state)
            }
        }
    }
}

private struct StatusIcon: View {
    let state: StreamActivityAttributes.ContentState

    var body: some View {
        Group {
            switch state.phase {
            case .streaming:
                Image(systemName: state.isMuted ? "mic.slash" : "mic")
            case .connecting, .reconnecting:
                Image(systemName: "antenna.radiowaves.left.and.right")
            }
        }
        .fontWeight(.medium)
        .foregroundStyle(state.tint)
    }
}

private extension StreamActivityAttributes.ContentState {
    var tint: Color {
        switch phase {
        case .streaming: isMuted ? .orange : .green
        case .connecting, .reconnecting: .blue
        }
    }
}

private struct ElapsedText: View {
    let state: StreamActivityAttributes.ContentState

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

/// Links open the app through its URL scheme, App Intent buttons need metadata xtool cannot generate
private struct ActionLinks: View {
    let state: StreamActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 8) {
            // Works like the mute toggle in the Phone app: highlighted while muted
            Link(destination: DeepLink.toggleMute.url) {
                Image(systemName: "mic.slash.fill")
                    .frame(width: 32, height: 32)
                    .foregroundStyle(state.isMuted ? .black : .white)
                    .background(state.isMuted ? Color.white : Color.white.opacity(0.2), in: Circle())
            }
            .accessibilityLabel(state.isMuted ? L10n.Common.unmute : L10n.Common.mute)
            Link(destination: DeepLink.disconnect.url) {
                Image(systemName: "xmark")
                    .frame(width: 32, height: 32)
                    .background(.red.opacity(0.85), in: Circle())
                    .foregroundStyle(.white)
            }
            .accessibilityLabel(L10n.Common.disconnect)
        }
        .font(.subheadline.weight(.semibold))
    }
}

private func phaseText(_ state: StreamActivityAttributes.ContentState) -> String {
    switch state.phase {
    case .connecting: L10n.Status.connecting
    case .reconnecting: L10n.Status.reconnecting
    case .streaming: state.isMuted ? L10n.Status.muted : L10n.Status.streaming
    }
}
