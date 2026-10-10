// SPDX-License-Identifier: GPL-3.0-or-later

import MicYouProtocol
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
                    Picker(L10n.Settings.transport, selection: $settings.transport) {
                        Text(L10n.Settings.tcpUDP).tag(TransportMode.tcpUDP)
                        Text(L10n.Settings.tcpOnly).tag(TransportMode.tcp)
                    }
                    if settings.transport == .tcpUDP {
                        Toggle(L10n.Settings.fec, isOn: $settings.fecEnabled)
                    }
                    Toggle(L10n.Settings.autoReconnect, isOn: $settings.autoReconnect)
                } header: {
                    Text(L10n.Settings.connection)
                } footer: {
                    Text(L10n.Settings.connectionFooter)
                }

                Section {
                    Picker(L10n.Settings.codec, selection: $settings.codec) {
                        Text(L10n.Settings.opus).tag(CodecChoice.opus)
                        Text(L10n.Settings.pcm).tag(CodecChoice.pcm)
                    }
                    if settings.codec == .opus {
                        Picker(L10n.Settings.bitrate, selection: $settings.opusBitrate) {
                            ForEach(AppSettings.opusBitrates, id: \.self) { rate in
                                Text(L10n.Unit.kbps(rate / 1000)).tag(rate)
                            }
                        }
                    }
                    Picker(L10n.Settings.sampleRate, selection: $settings.sampleRate) {
                        ForEach(AppSettings.sampleRates, id: \.self) { rate in
                            Text(L10n.Unit.kHz(rate)).tag(rate)
                        }
                    }
                    Picker(L10n.Settings.channels, selection: $settings.stereo) {
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
                    VStack(alignment: .leading) {
                        LabeledContent(L10n.Settings.inputGain) {
                            Text(L10n.Unit.signedDB(settings.inputGainDB))
                                .monospacedDigit()
                        }
                        Slider(
                            value: Binding(get: { settings.inputGainDB }, set: { model.setInputGain($0.rounded()) }),
                            in: 0...24,
                            step: 1
                        ) {
                            Text(L10n.Settings.inputGain)
                        } minimumValueLabel: {
                            Image(systemName: "speaker.wave.1")
                        } maximumValueLabel: {
                            Image(systemName: "speaker.wave.3")
                        }
                    }
                } header: {
                    Text(L10n.Settings.microphone)
                } footer: {
                    Text(L10n.Settings.inputGainFooter)
                }

                Section {
                    Toggle(L10n.Settings.voiceProcessing, isOn: $settings.voiceProcessing)
                } footer: {
                    Text(L10n.Settings.voiceProcessingFooter)
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

struct AboutView: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return L10n.About.versionValue(short, build: build)
    }

    var body: some View {
        Form {
            Section {
                LabeledContent(L10n.About.version, value: version)
                LabeledContent(L10n.About.protocolLabel, value: L10n.About.protocolValue)
                LabeledContent(L10n.About.defaultPort, value: String(MicYouWire.defaultPort))
            }
            Section {
                Link(destination: URL(string: "https://github.com/MicYou-Dev/MicYou")!) {
                    Label(L10n.About.desktop, systemImage: "desktopcomputer")
                }
                Link(destination: URL(string: "https://github.com/MicYou-Dev/MicYou-iOS")!) {
                    Label(L10n.About.sourceCode, systemImage: "chevron.left.forwardslash.chevron.right")
                }
                Link(destination: URL(string: "https://www.gnu.org/licenses/gpl-3.0.html")!) {
                    Label(L10n.About.license, systemImage: "doc.text")
                }
            } footer: {
                Text(L10n.About.footer)
            }
        }
        .navigationTitle(L10n.About.title)
    }
}
