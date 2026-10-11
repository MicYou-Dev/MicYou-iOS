// SPDX-License-Identifier: GPL-3.0-or-later

import AVFoundation
import MicYouCore
import MicYouShared
import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var presetTaps = 0

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                if model.isActive {
                    Section {
                        Label(L10n.Settings.appliesNextTime, systemImage: "info.circle")
                            .font(.subheadline)
                        if model.hasPendingChanges {
                            Button(L10n.Settings.reconnectToApply, systemImage: "arrow.clockwise") {
                                model.restart()
                            }
                        }
                    }
                    .animation(Motion.state, value: model.hasPendingChanges)
                }

                Section {
                    HStack(spacing: 8) {
                        ForEach(StreamPreset.allCases) { preset in
                            PresetCard(preset: preset, isSelected: settings.matchingPreset == preset) {
                                presetTaps += 1
                                withAnimation(Motion.state) { settings.apply(preset) }
                            }
                        }
                    }
                    .sensoryFeedback(.selection, trigger: presetTaps)
                    // Inset so the cards sit inside the section's rounded corners instead of being clipped by them
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                } header: {
                    Text(L10n.Settings.presets)
                } footer: {
                    Text(L10n.Settings.presetFooter)
                }

                Section {
                    SegmentedRow(title: L10n.Settings.transport, selection: $settings.transport) {
                        ForEach(TransportMode.allCases) { Text($0.title).tag($0) }
                    }
                    // Disabled rather than removed, so switching presets does not make the list jump
                    Toggle(L10n.Settings.fec, isOn: $settings.fecEnabled)
                        .disabled(settings.transport != .tcpUDP)
                    Toggle(L10n.Settings.autoReconnect, isOn: $settings.autoReconnect)
                    Toggle(isOn: $settings.autoConnect) {
                        Text(L10n.Settings.autoConnect)
                        Text(L10n.Settings.autoConnectDetail)
                    }
                } header: {
                    Text(L10n.Settings.connection)
                } footer: {
                    Text(L10n.Settings.connectionFooter)
                }

                Section {
                    SegmentedRow(title: L10n.Settings.codec, selection: $settings.codec) {
                        ForEach(CodecChoice.allCases) { Text($0.title).tag($0) }
                    }
                    SegmentedRow(title: L10n.Settings.bitrate, selection: $settings.opusBitrate) {
                        ForEach(AppSettings.opusBitrates, id: \.self) { rate in
                            Text(L10n.Unit.kbps(rate / 1000)).tag(rate)
                        }
                    }
                    .disabled(settings.codec != .opus)
                    SegmentedRow(title: L10n.Settings.sampleRate, selection: $settings.sampleRate) {
                        ForEach(AppSettings.sampleRates, id: \.self) { rate in
                            Text(L10n.Unit.kHz(rate)).tag(rate)
                        }
                    }
                    SegmentedRow(title: L10n.Settings.channels, selection: $settings.stereo) {
                        Text(L10n.Common.mono).tag(false)
                        Text(L10n.Common.stereo).tag(true)
                    }
                } header: {
                    Text(L10n.Settings.audio)
                } footer: {
                    if settings.codec == .opus && settings.sampleRate == 44100 {
                        Text(L10n.Settings.opusNo44Footer)
                    } else {
                        Text(L10n.Settings.audioFooter)
                    }
                }

                Section {
                    InputPicker()
                    InputGainControl()
                    Toggle(isOn: $settings.voiceProcessing) {
                        Text(L10n.Settings.voiceProcessing)
                        Text(L10n.Settings.voiceProcessingFooter)
                    }
                    if settings.voiceProcessing {
                        MicrophoneModeRow()
                    }
                } header: {
                    Text(L10n.Settings.microphone)
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.Settings.inputGainFooter)
                        if settings.voiceProcessing {
                            Text(L10n.Settings.micModeFooter)
                        }
                    }
                }

                Section {
                    Toggle(L10n.Settings.keepScreenOn, isOn: $settings.keepScreenOn)
                    Toggle(L10n.Settings.liveActivity, isOn: $settings.liveActivity)
                } header: {
                    Text(L10n.Settings.general)
                } footer: {
                    Text(L10n.Settings.generalFooter)
                }

                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label(L10n.About.title, systemImage: "info.circle")
                    }
                }
            }
            .navigationTitle(L10n.Common.settings)
            .navigationBarTitleDisplayMode(.inline)
            // Replaying the introduction from the about page needs the home screen
            .onChange(of: settings.welcomeShown) { _, shown in
                if !shown { dismiss() }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.done) { dismiss() }
                }
            }
        }
    }
}

/// The microphone to record from, switches right away while streaming
private struct InputPicker: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings

    var body: some View {
        Picker(selection: Binding(get: { settings.input }, set: { model.setInput($0) })) {
            ForEach(model.inputChoices) { option in
                Label(option.name, systemImage: option.symbol)
                    .tag(option.preference)
            }
        } label: {
            Text(L10n.Settings.input)
        }
        .task { model.refreshInputOptions() }
    }
}

/// The system microphone mode, such as Voice Isolation, which only the user can change in Control Center
/// It only applies to voice processing input, so the mode is shown while such a stream runs
private struct MicrophoneModeRow: View {
    @Environment(AppModel.self) private var model
    @State private var mode = AVCaptureDevice.activeMicrophoneMode

    var body: some View {
        LabeledContent(L10n.Settings.micMode, value: model.isVoiceProcessingActive ? mode.title ?? "" : "")
            .trackingMicrophoneMode($mode, while: model.isVoiceProcessingActive)
    }
}

/// A label above a full width segmented control, so every choice is visible without opening a menu
private struct SegmentedRow<Value: Hashable, Options: View>: View {
    let title: String
    @Binding var selection: Value
    @ViewBuilder var options: Options

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
            Picker(title, selection: $selection) {
                options
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}

/// One of the presets at the top of the settings, outlined when the current settings match it
private struct PresetCard: View {
    let preset: StreamPreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Text(preset.title)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                VStack(alignment: .leading, spacing: 1) {
                    Text(preset.transport.title)
                    Text(codec)
                }
                .font(.caption)
                .opacity(0.75)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .glassSurface(in: Self.shape, tint: isSelected ? .accentColor : nil, fallback: .fill.tertiary)
            .contentShape(Self.shape)
        }
        .buttonStyle(.surface)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// Concentric with the section around it, which the row insets by 8 points
    private static let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

    private var codec: String {
        let detail = preset.codec == .opus ? L10n.Unit.kbps(preset.opusBitrate / 1000) : L10n.Unit.kHz(preset.sampleRate)
        return L10n.Common.codecAndRate(preset.codec.shortName, detail)
    }
}
