// SPDX-License-Identifier: GPL-3.0-or-later

import MicYouShared
import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                if model.isActive {
                    Section {
                        Label(L10n.Settings.appliesNextTime, systemImage: "info.circle")
                            .font(.subheadline)
                    }
                }

                Section {
                    HStack(spacing: 8) {
                        ForEach(StreamPreset.allCases) { preset in
                            PresetCard(preset: preset, isSelected: settings.matchingPreset == preset) {
                                withAnimation { settings.apply(preset) }
                            }
                        }
                    }
                    // Inset so the cards sit inside the section's rounded corners instead of being clipped by them
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                } header: {
                    Text(L10n.Settings.presets)
                } footer: {
                    Text(L10n.Settings.presetFooter)
                }

                Section {
                    SegmentedRow(title: L10n.Settings.transport, selection: $settings.transport) {
                        Text(L10n.Settings.tcpUDP).tag(TransportMode.tcpUDP)
                        Text(L10n.Settings.tcpOnly).tag(TransportMode.tcp)
                    }
                    // Disabled rather than removed, so switching presets does not make the list jump
                    Toggle(L10n.Settings.fec, isOn: $settings.fecEnabled)
                        .disabled(settings.transport != .tcpUDP)
                    Toggle(L10n.Settings.autoReconnect, isOn: $settings.autoReconnect)
                } header: {
                    Text(L10n.Settings.connection)
                } footer: {
                    Text(L10n.Settings.connectionFooter)
                }

                Section {
                    SegmentedRow(title: L10n.Settings.codec, selection: $settings.codec) {
                        Text(L10n.Settings.opus).tag(CodecChoice.opus)
                        Text(L10n.Settings.pcm).tag(CodecChoice.pcm)
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
                    InputGainControl()
                    Toggle(isOn: $settings.voiceProcessing) {
                        Text(L10n.Settings.voiceProcessing)
                        Text(L10n.Settings.voiceProcessingFooter)
                    }
                } header: {
                    Text(L10n.Settings.microphone)
                } footer: {
                    Text(L10n.Settings.inputGainFooter)
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
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.done) { dismiss() }
                }
            }
        }
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
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                VStack(alignment: .leading, spacing: 1) {
                    Text(preset.transport == .tcpUDP ? L10n.Settings.tcpUDP : L10n.Settings.tcpOnly)
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
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// Concentric with the section around it, which the row insets by 8 points
    private static let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

    private var title: String {
        switch preset {
        case .lowLatency: L10n.Settings.presetLowLatency
        case .stable: L10n.Settings.presetStable
        case .lossless: L10n.Settings.presetLossless
        }
    }

    private var codec: String {
        switch preset.codec {
        case .opus: L10n.Common.codecAndRate(L10n.Settings.opus, L10n.Unit.kbps(preset.opusBitrate / 1000))
        case .pcm: L10n.Common.codecAndRate(L10n.Settings.pcmShort, L10n.Unit.kHz(preset.sampleRate))
        }
    }
}
