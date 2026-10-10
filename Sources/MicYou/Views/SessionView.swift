// SPDX-License-Identifier: GPL-3.0-or-later

import MicYouShared
import SwiftUI

/// The live session: elapsed time, input level, stream facts and input gain
/// Every phase uses the same layout, only the contents of each slot change, so nothing jumps while connecting or reconnecting
struct SessionView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)
            VStack(spacing: 6) {
                target
                ElapsedTime(since: model.streamingSince, isLive: model.phase == .streaming)
            }
            levelSlot
            if let notice = model.notice {
                NoticeCard(text: notice, kind: .info) {
                    withAnimation { model.notice = nil }
                }
            }
            StreamStats()
                .opacity(model.phase == .streaming ? 1 : 0.5)
            InputGainControl()
                .padding(16)
                .background(.card, in: .rect(cornerRadius: 16))
            Spacer(minLength: 0)
        }
        .animation(.smooth, value: model.phase)
        .animation(.smooth, value: model.isMuted)
    }

    @ViewBuilder
    private var target: some View {
        if let name = model.connectedName {
            Label {
                Text(L10n.Common.joined([name, model.remoteAddress == name ? "" : model.remoteAddress ?? ""]))
            } icon: {
                Image(systemName: "desktopcomputer")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
    }

    /// The meter, or the retry progress while reconnecting, in a slot of fixed minimum height
    private var levelSlot: some View {
        VStack(spacing: 8) {
            if case .reconnecting(let attempt) = model.phase {
                ReconnectProgress(attempt: attempt)
                caption(L10n.Status.reconnectDetail, systemImage: "antenna.radiowaves.left.and.right", color: .blue)
            } else {
                // Capture keeps running while connecting, the meter only moves once audio reaches the computer
                LevelMeterView(levelDB: model.phase == .streaming && !model.isMuted ? model.levelDB : -160)
                    .frame(height: 44)
                    .opacity(model.isMuted ? 0.4 : 1)
                if model.isMuted {
                    caption(L10n.Status.mutedDetail, systemImage: "mic.slash.fill", color: .orange)
                } else {
                    MeterScale()
                }
            }
        }
        .frame(minHeight: 96, alignment: .top)
    }

    private func caption(_ text: String, systemImage: String, color: Color) -> some View {
        Label {
            Text(text)
                .foregroundStyle(.secondary)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(color)
        }
        .font(.footnote)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .transition(.opacity)
    }
}

/// Phase of the session as a glass capsule with a colored dot
struct StatusPill: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 8) {
            if isWaiting {
                ProgressView()
                    .controlSize(.mini)
                    .tint(tint)
            } else {
                Circle()
                    .fill(tint)
                    .frame(width: 8, height: 8)
            }
            Text(title)
                .contentTransition(.opacity)
        }
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 14)
        .frame(minHeight: 36)
        .glassSurface(in: .capsule, interactive: false, fallback: tint.opacity(0.15))
        .animation(.smooth, value: tint)
        .accessibilityElement(children: .combine)
    }

    private var isWaiting: Bool {
        model.phase != .streaming
    }

    private var tint: Color {
        switch model.phase {
        case .streaming: model.isMuted ? .orange : .green
        default: .blue
        }
    }

    private var title: String {
        switch model.phase {
        case .streaming: model.isMuted ? L10n.Status.muted : L10n.Status.streaming
        case .reconnecting(let attempt): L10n.Status.reconnectingAttempt(attempt, of: AppModel.maxReconnectAttempts)
        default: L10n.Status.connecting
        }
    }
}

/// Large elapsed time, dimmed until audio flows again
private struct ElapsedTime: View {
    let since: Date?
    let isLive: Bool

    var body: some View {
        Group {
            if let since {
                // Not Text(timerInterval:), which may claim more width than it shows
                TimelineView(.periodic(from: since, by: 1)) { context in
                    Text(Self.elapsed(from: since, to: context.date))
                }
            } else {
                Text(Self.elapsed(from: .now, to: .now))
            }
        }
        .font(.system(size: 76, weight: .medium))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .foregroundStyle(isLive ? .primary : .tertiary)
        .accessibilityLabel(L10n.Status.duration)
    }

    /// "0:06", "12:34" or "1:02:03"
    private static func elapsed(from start: Date, to now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        let pattern: Duration.TimeFormatStyle.Pattern = seconds >= 3600 ? .hourMinuteSecond : .minuteSecond
        return Duration.seconds(seconds).formatted(.time(pattern: pattern))
    }
}

/// One bar per reconnect attempt, filled up to the current one
private struct ReconnectProgress: View {
    let attempt: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...AppModel.maxReconnectAttempts, id: \.self) { index in
                Capsule()
                    .fill(index <= attempt ? AnyShapeStyle(.blue) : AnyShapeStyle(.fill.tertiary))
                    .frame(height: 6)
            }
        }
        .frame(maxWidth: 264)
        // Same height as the meter it replaces
        .frame(height: 44)
        .accessibilityElement()
        .accessibilityLabel(L10n.Status.reconnectingAttempt(attempt, of: AppModel.maxReconnectAttempts))
    }
}

/// Format, bitrate, transport and microphone of the stream, shown from the start of a connection
private struct StreamStats: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow {
                StatTile(label: L10n.Status.formatLabel, value: format)
                StatTile(label: L10n.Status.bitrate, value: L10n.Unit.kbps(model.throughput / 1000))
            }
            GridRow {
                StatTile(label: L10n.Status.transport, value: transport)
                StatTile(label: L10n.Settings.microphone, value: model.audioInput?.name ?? "")
            }
        }
    }

    /// What the computer accepted once streaming, what was asked for before that
    private var format: String {
        if let format = model.activeFormat {
            return L10n.Common.joined([StreamText.codecAndRate(format), format.channelCount == 2 ? L10n.Common.stereo : ""])
        }
        guard let config = model.streamConfig else { return "" }
        let codec = config.codec == .opus ? L10n.Settings.opus : L10n.Settings.pcmShort
        return L10n.Common.joined([
            L10n.Common.codecAndRate(codec, L10n.Unit.kHz(config.sampleRate)),
            config.channels == 2 ? L10n.Common.stereo : "",
        ])
    }

    private var transport: String {
        guard let config = model.streamConfig else { return "" }
        switch config.transport {
        case .tcpUDP: return L10n.Common.joined([L10n.Activity.udp, config.fecEnabled ? L10n.Status.fec : ""])
        case .tcp: return L10n.Settings.tcpOnly
        }
    }
}

private struct StatTile: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.card, in: .rect(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}

/// Software gain slider, applies immediately, shared with the settings screen
struct InputGainControl: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            LabeledContent(L10n.Settings.inputGain) {
                Text(L10n.Unit.signedDB(settings.inputGainDB))
                    .monospacedDigit()
            }
            Slider(
                value: Binding(get: { settings.inputGainDB }, set: { model.setInputGain($0.rounded()) }),
                in: AppSettings.inputGainRange,
                step: 1
            ) {
                Text(L10n.Settings.inputGain)
            } minimumValueLabel: {
                Image(systemName: "speaker.wave.1")
            } maximumValueLabel: {
                Image(systemName: "speaker.wave.3")
            }
            .foregroundStyle(.secondary)
        }
    }
}
