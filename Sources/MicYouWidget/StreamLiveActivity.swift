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
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ElapsedText(state: state)
                        .font(.headline)
                        .frame(maxWidth: 80, alignment: .trailing)
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
            .keylineTint(state.isMuted ? .orange : .green)
        }
    }
}

private struct LockScreenView: View {
    let context: ActivityViewContext<StreamActivityAttributes>

    var body: some View {
        let state = context.state
        HStack(spacing: 12) {
            StatusIcon(state: state)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(.fill.tertiary, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.serverName)
                    .font(.headline)
                    .lineLimit(1)
                Text(phaseText(state) + (state.detail.isEmpty ? "" : " · \(state.detail)"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
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
        switch state.phase {
        case .streaming:
            Image(systemName: state.isMuted ? "mic.slash.fill" : "mic.fill")
                .foregroundStyle(state.isMuted ? .orange : .green)
        case .connecting, .reconnecting:
            Image(systemName: "antenna.radiowaves.left.and.right")
                .foregroundStyle(.blue)
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
            Text("…")
        }
    }
}

/// Links open the app through its URL scheme, App Intent buttons need metadata xtool cannot generate
private struct ActionLinks: View {
    let state: StreamActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 8) {
            Link(destination: DeepLink.toggleMute.url) {
                Image(systemName: state.isMuted ? "mic.fill" : "mic.slash.fill")
                    .frame(width: 32, height: 32)
                    .background(.fill.secondary, in: Circle())
            }
            .accessibilityLabel(state.isMuted ? Text("Unmute") : Text("Mute"))
            Link(destination: DeepLink.disconnect.url) {
                Image(systemName: "xmark")
                    .frame(width: 32, height: 32)
                    .background(.red.opacity(0.85), in: Circle())
                    .foregroundStyle(.white)
            }
            .accessibilityLabel(Text("Disconnect"))
        }
        .font(.subheadline.weight(.semibold))
    }
}

private func phaseText(_ state: StreamActivityAttributes.ContentState) -> String {
    switch state.phase {
    case .connecting: String(localized: "Connecting…")
    case .reconnecting: String(localized: "Reconnecting…")
    case .streaming: state.isMuted ? String(localized: "Muted") : String(localized: "Streaming")
    }
}
