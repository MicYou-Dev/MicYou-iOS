// SPDX-License-Identifier: GPL-3.0-or-later

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
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if model.isActive {
                    LevelMeterView(levelDB: model.isMuted ? -160 : model.levelDB)
                        .frame(height: 6)
                        .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 6)

        if model.phase == .streaming {
            if let since = model.streamingSince {
                LabeledContent("Duration") {
                    Text(timerInterval: since...Date.distantFuture, countsDown: false)
                        .monospacedDigit()
                }
            }
            if let format = model.activeFormat {
                LabeledContent("Format", value: FormatText.short(format) + (format.channelCount == 2 ? " · " + String(localized: "Stereo") : ""))
            }
            LabeledContent("Bitrate") {
                Text("\(model.throughput / 1000) kbps").monospacedDigit()
            }
        }
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
        case .idle: String(localized: "Not Connected")
        case .connecting: String(localized: "Connecting…")
        case .streaming: model.isMuted ? String(localized: "Muted") : String(localized: "Streaming")
        case .reconnecting(let attempt): String(localized: "Reconnecting (\(attempt)/\(AppModel.maxReconnectAttempts))…")
        case .failed: String(localized: "Connection Failed")
        }
    }

    private var subtitle: String? {
        guard model.isActive, let name = model.connectedName else {
            return model.phase == .idle ? String(localized: "Turn your iPhone into a microphone for your computer") : nil
        }
        if let address = model.remoteAddress, address != name {
            return "\(name) · \(address)"
        }
        return name
    }
}

struct LevelMeterView: View {
    /// Input level in dBFS, shown on a -60...0 dB scale
    var levelDB: Float

    var body: some View {
        GeometryReader { proxy in
            let fraction = CGFloat(max(0, min(1, (levelDB + 60) / 60)))
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(color)
                    .frame(width: proxy.size.width * fraction)
                    .animation(.linear(duration: 0.08), value: fraction)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Input Level")
        .accessibilityValue("\(Int(levelDB.rounded())) dB")
    }

    private var color: Color {
        if levelDB >= -6 { return .red }
        if levelDB >= -18 { return .yellow }
        return .green
    }
}
