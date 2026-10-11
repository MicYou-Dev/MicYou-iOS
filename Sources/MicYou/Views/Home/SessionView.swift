// SPDX-License-Identifier: GPL-3.0-or-later

import AVFoundation
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
                    withAnimation(Motion.state) { model.notice = nil }
                }
                .adaptiveTransition(.notice)
            }
            StreamStats()
                .opacity(model.phase == .streaming ? 1 : 0.5)
            InputGainControl()
                .padding(16)
                .background(.card, in: .rect(cornerRadius: 16))
            Spacer(minLength: 0)
        }
        .animation(Motion.state, value: model.phase)
        .animation(Motion.state, value: model.isMuted)
        .animation(Motion.state, value: model.notice)
        .animation(Motion.state, value: model.captureStatus)
    }

    @ViewBuilder
    private var target: some View {
        if let name = model.connectedName {
            Label {
                Text(L10n.Common.joined([name, model.remoteAddress == name ? "" : model.remoteAddress ?? ""]))
                    .contentTransition(.opacity)
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
                LevelMeterView(levelDB: isLive ? model.levelDB : -160)
                    .frame(height: 44)
                    .opacity(model.isMuted || model.captureStatus != .running ? 0.4 : 1)
                switch model.captureStatus {
                case .interrupted:
                    caption(L10n.Status.interruptedDetail, systemImage: "pause.fill", color: .yellow)
                    // Not every interruption reports its end
                    resumeButton
                case .resumeFailed:
                    caption(L10n.Status.resumeFailedDetail, systemImage: "exclamationmark.triangle.fill", color: .red)
                    resumeButton
                case .running:
                    if model.isMuted {
                        caption(L10n.Status.mutedDetail, systemImage: "mic.slash.fill", color: .orange)
                    } else {
                        MeterScale()
                    }
                }
            }
        }
        .frame(minHeight: 96, alignment: .top)
    }

    private var resumeButton: some View {
        Button(L10n.Common.resume, systemImage: "arrow.clockwise") {
            model.resumeCapture()
        }
        .glassButtonStyle()
        .controlSize(.small)
        .transition(.opacity)
    }

    /// Audio is reaching the computer
    private var isLive: Bool {
        model.phase == .streaming && !model.isMuted && model.captureStatus == .running
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
            Group {
                if isWaiting {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(tint)
                } else {
                    Circle()
                        .fill(tint)
                        .frame(width: 8, height: 8)
                }
            }
            .transition(.scale(scale: 0.5).combined(with: .opacity))
            // Rolls the attempt count instead of fading the whole label
            Text(title)
                .contentTransition(.numericText())
        }
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 14)
        .frame(minHeight: 36)
        .glassSurface(in: .capsule, interactive: false, fallback: tint.opacity(0.15))
        // The capsule resizes with the label, both animate together
        .adaptiveAnimation(value: title)
        .animation(Motion.state, value: tint)
        .accessibilityElement(children: .combine)
    }

    private var isWaiting: Bool {
        model.phase != .streaming
    }

    private var tint: Color {
        switch model.phase {
        case .streaming: model.captureStatus != .running ? .yellow : model.isMuted ? .orange : .green
        default: .blue
        }
    }

    private var title: String {
        switch model.phase {
        case .streaming:
            model.captureStatus != .running ? L10n.Status.interrupted : model.isMuted ? L10n.Status.muted : L10n.Status.streaming
        case .reconnecting(let attempt): L10n.Status.reconnectingAttempt(attempt, of: AppModel.maxReconnectAttempts)
        default: L10n.Status.connecting
        }
    }
}

/// Large elapsed time, dimmed until audio flows again
private struct ElapsedTime: View {
    let since: Date?
    let isLive: Bool
    /// Follows Dynamic Type, the minimum scale factor still fits long sessions on one line
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 76

    var body: some View {
        // One view for every state, so starting the clock does not swap views
        // Ticks on the second boundaries of the stream, not of the moment the view appeared
        TimelineView(.periodic(from: since ?? .now, by: 1)) { context in
            let text = Self.elapsed(from: since ?? context.date, to: context.date)
            // Not Text(timerInterval:), which may claim more width than it shows
            Text(text)
                .contentTransition(.numericText(countsDown: false))
                .adaptiveAnimation(.smooth(duration: 0.35), value: text)
        }
        .font(.system(size: size, weight: .medium))
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...AppModel.maxReconnectAttempts, id: \.self) { index in
                let bar = Capsule()
                    .fill(index <= attempt ? AnyShapeStyle(.blue) : AnyShapeStyle(.fill.tertiary))
                    .frame(height: 6)
                // The current attempt breathes, so the long waits between retries do not look frozen
                if index == attempt && !reduceMotion {
                    bar.phaseAnimator([1, 0.35]) { content, opacity in
                        content.opacity(opacity)
                    } animation: { _ in
                        .easeInOut(duration: 0.8)
                    }
                } else {
                    bar
                }
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
    @Environment(AppSettings.self) private var settings
    @State private var micMode = AVCaptureDevice.activeMicrophoneMode
    @State private var showsMicModeHint = false

    var body: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow {
                StatTile(label: L10n.Status.formatLabel, value: format)
                StatTile(label: L10n.Status.bitrate, value: L10n.Unit.kbps(model.throughput / 1000), isNumeric: true)
            }
            GridRow {
                StatTile(label: L10n.Status.transport, value: transport)
                // Tapping the microphone switches it, for example to the back microphone or a headset
                Menu {
                    Picker(L10n.Settings.input, selection: Binding(get: { settings.input }, set: { model.setInput($0) })) {
                        ForEach(model.inputChoices) { option in
                            Label(option.name, systemImage: option.symbol)
                                .tag(option.preference)
                        }
                    }
                } label: {
                    StatTile(label: L10n.Settings.microphone, value: model.audioInput?.name ?? "", accessory: "chevron.up.chevron.down")
                }
                .buttonStyle(.plain)
                .task { model.refreshInputOptions() }
            }
            // System microphone modes only apply to voice processing input
            // Only Control Center can change them, the tile explains where
            if model.isVoiceProcessingActive {
                GridRow {
                    Button {
                        showsMicModeHint = true
                    } label: {
                        StatTile(label: L10n.Settings.micMode, value: micMode.title ?? "", accessory: "info.circle")
                    }
                    .buttonStyle(.plain)
                    .gridCellColumns(2)
                    .accessibilityHint(L10n.Settings.micModeFooter)
                    .popover(isPresented: $showsMicModeHint) {
                        Text(L10n.Settings.micModeFooter)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(idealWidth: 300)
                            .padding()
                            .presentationCompactAdaptation(.popover)
                    }
                }
                .transition(.opacity)
            }
        }
        .trackingMicrophoneMode($micMode, while: model.isVoiceProcessingActive)
    }

    /// What the computer accepted once streaming, what was asked for before that
    private var format: String {
        guard let format = model.activeFormat ?? model.streamConfig?.requestedFormat else { return "" }
        return StreamText.format(format)
    }

    private var transport: String {
        guard let config = model.streamConfig else { return "" }
        return StreamText.transport(config.transport, fec: config.fecEnabled)
    }
}

private struct StatTile: View {
    let label: String
    let value: String
    /// Rolls the digits of values that update every second
    var isNumeric = false
    /// SF Symbol after the label for tiles that open something, such as a menu
    var accessory: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text(label)
                if let accessory {
                    Spacer(minLength: 0)
                    Image(systemName: accessory)
                        .imageScale(.small)
                        .accessibilityHidden(true)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            // A placeholder keeps the tile height while the value is not known yet
            Text(value.isEmpty ? L10n.Status.waiting : value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(value.isEmpty ? .tertiary : .primary)
                .contentTransition(isNumeric ? .numericText() : .opacity)
                .adaptiveAnimation(value: value)
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
