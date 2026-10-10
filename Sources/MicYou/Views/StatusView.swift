// SPDX-License-Identifier: GPL-3.0-or-later

import MicYouShared
import SwiftUI

struct StatusView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
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
                if model.isActive {
                    LevelMeterView(levelDB: model.isMuted ? -160 : model.levelDB)
                        .frame(height: 6)
                        .padding(.top, 4)
                }
            }
        }
        .padding(.vertical, 6)
        .animation(.default, value: model.phase)

        if model.phase == .streaming {
            HStack(alignment: .top) {
                if let since = model.streamingSince {
                    StatCell(label: L10n.Status.duration) {
                        Text(timerInterval: since...Date.distantFuture, countsDown: false)
                    }
                }
                if let format = model.activeFormat {
                    StatCell(label: L10n.Status.formatLabel) {
                        Text(L10n.Common.joined([FormatText.short(format), format.channelCount == 2 ? L10n.Common.stereo : ""]))
                    }
                }
                StatCell(label: L10n.Status.bitrate) {
                    Text(L10n.Unit.kbps(model.throughput / 1000))
                }
            }
            .padding(.vertical, 2)
        }
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct LevelMeterView: View {
    /// Input level in dBFS, shown on a -60...0 dB scale
    var levelDB: Float
    @State private var ballistics = MeterBallistics()

    var body: some View {
        // Redraws every frame while the meter moves so it glides between the 30 Hz level updates
        TimelineView(.animation(paused: ballistics.isSettled(at: levelDB))) { timeline in
            let shown = ballistics.advance(to: levelDB, at: timeline.date)
            GeometryReader { proxy in
                let fraction = CGFloat(max(0, min(1, (shown + 60) / 60)))
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    // Green up to -18 dB, yellow to -6 dB, then red, revealed from the left
                    LinearGradient(stops: [
                        .init(color: .green, location: 0),
                        .init(color: .green, location: 0.65),
                        .init(color: .yellow, location: 0.75),
                        .init(color: .yellow, location: 0.85),
                        .init(color: .red, location: 0.95),
                    ], startPoint: .leading, endPoint: .trailing)
                    .mask(alignment: .leading) {
                        Capsule().frame(width: proxy.size.width * fraction)
                    }
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel(L10n.Status.inputLevel)
        .accessibilityValue(L10n.Unit.dB(Int(levelDB.rounded())))
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
