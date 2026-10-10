// SPDX-License-Identifier: GPL-3.0-or-later

import MicYouShared
import SwiftUI

struct StatusView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        // One list row, so the divider spans the card instead of starting at the title
        VStack(alignment: .leading, spacing: 14) {
            header
            if model.phase == .streaming {
                Divider()
                // Sit nearer the bottom edge, the row inset already pads below
                stats
                    .padding(.top, 4)
            }
        }
        .padding(.top, 6)
        .padding(.bottom, model.phase == .streaming ? 0 : 6)
        .animation(.default, value: model.phase)
    }

    private var header: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.15))
                Image(systemName: symbol)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(tint)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.pulse, isActive: isWaiting)
            }
            .frame(width: 56, height: 56)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(isFailed ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                        .lineLimit(isFailed ? nil : 2)
                        .fixedSize(horizontal: false, vertical: isFailed)
                }
                // Only while audio actually reaches the computer, capture keeps running during reconnects
                if model.phase == .streaming {
                    LevelMeterView(levelDB: model.isMuted ? -160 : model.levelDB)
                        .frame(height: 6)
                        .padding(.top, 4)
                }
            }
        }
    }

    /// Cells take their natural width and share the leftover space, so the format is not cut off
    private var stats: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            if let since = model.streamingSince {
                StatCell(label: L10n.Status.duration) {
                    // Not Text(timerInterval:), which may claim more width than it shows
                    TimelineView(.periodic(from: since, by: 1)) { context in
                        Text(Self.elapsed(from: since, to: context.date))
                    }
                }
                Spacer(minLength: 12)
            }
            if let format = model.activeFormat {
                StatCell(label: L10n.Status.formatLabel) {
                    Text(L10n.Common.joined([StreamText.codecAndRate(format), format.channelCount == 2 ? L10n.Common.stereo : ""]))
                }
                .layoutPriority(1)
                Spacer(minLength: 12)
            }
            StatCell(label: L10n.Status.bitrate) {
                Text(L10n.Unit.kbps(model.throughput / 1000))
            }
        }
    }

    /// "0:06", "12:34" or "1:02:03"
    private static func elapsed(from start: Date, to now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        let pattern: Duration.TimeFormatStyle.Pattern = seconds >= 3600 ? .hourMinuteSecond : .minuteSecond
        return Duration.seconds(seconds).formatted(.time(pattern: pattern))
    }

    private var isFailed: Bool {
        if case .failed = model.phase { true } else { false }
    }

    private var isWaiting: Bool {
        switch model.phase {
        case .connecting, .reconnecting: true
        default: false
        }
    }

    private var tint: Color {
        switch model.phase {
        case .streaming: model.isMuted ? .orange : .green
        case .connecting, .reconnecting: .blue
        case .failed: .red
        case .idle: .secondary
        }
    }

    private var symbol: String {
        switch model.phase {
        case .streaming: model.isMuted ? "mic.slash.fill" : "waveform"
        case .connecting, .reconnecting: "antenna.radiowaves.left.and.right"
        case .failed: "exclamationmark.triangle.fill"
        case .idle: "mic"
        }
    }

    private var title: String {
        switch model.phase {
        case .idle: L10n.Status.notConnected
        case .connecting: L10n.Status.connecting
        case .streaming: model.isMuted ? L10n.Status.muted : L10n.Status.streaming
        case .reconnecting(let attempt): L10n.Status.reconnectingAttempt(attempt, of: AppModel.maxReconnectAttempts)
        case .failed: L10n.Status.failed
        }
    }

    private var subtitle: String? {
        switch model.phase {
        case .failed(let message):
            return message
        case .idle:
            if let name = model.selectedName {
                return L10n.Status.ready(name)
            }
            return L10n.App.tagline
        case .connecting, .streaming, .reconnecting:
            guard let name = model.connectedName else { return nil }
            if let address = model.remoteAddress, address != name {
                return L10n.Common.joined([name, address])
            }
            return name
        }
    }
}

/// A small value over caption pair used in the streaming stats row
private struct StatCell<Value: View>: View {
    let label: String
    @ViewBuilder var value: Value

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            value
                .font(.callout.weight(.medium))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
