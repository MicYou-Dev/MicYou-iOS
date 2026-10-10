// SPDX-License-Identifier: GPL-3.0-or-later

import MicYouProtocol
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
                        Label("Connection and audio changes apply the next time you connect.", systemImage: "info.circle")
                            .font(.subheadline)
                    }
                }

                Section {
                    Picker("Transport", selection: $settings.transport) {
                        Text("TCP + UDP").tag(TransportMode.tcpUDP)
                        Text("TCP Only").tag(TransportMode.tcp)
                    }
                    if settings.transport == .tcpUDP {
                        Toggle("Forward Error Correction", isOn: $settings.fecEnabled)
                    }
                    Toggle("Reconnect Automatically", isOn: $settings.autoReconnect)
                } header: {
                    Text("Connection")
                } footer: {
                    Text("TCP + UDP has the lowest latency. Switch to TCP Only if audio drops out on your network. Error correction adds about 8% traffic to recover lost packets.")
                }

                Section {
                    Picker("Codec", selection: $settings.codec) {
                        Text("Opus").tag(CodecChoice.opus)
                        Text("PCM (Uncompressed)").tag(CodecChoice.pcm)
                    }
                    if settings.codec == .opus {
                        Picker("Bitrate", selection: $settings.opusBitrate) {
                            ForEach(AppSettings.opusBitrates, id: \.self) { rate in
                                Text("\(rate / 1000) kbps").tag(rate)
                            }
                        }
                    }
                    Picker("Sample Rate", selection: $settings.sampleRate) {
                        ForEach(AppSettings.sampleRates, id: \.self) { rate in
                            Text(rateLabel(rate)).tag(rate)
                        }
                    }
                    Picker("Channels", selection: $settings.stereo) {
                        Text("Mono").tag(false)
                        Text("Stereo").tag(true)
                    }
                } header: {
                    Text("Audio")
                } footer: {
                    if settings.codec == .opus && settings.sampleRate == 44100 {
                        Text("Opus does not support 44.1 kHz, 48 kHz is used instead.")
                    } else {
                        Text("Opus uses far less bandwidth than PCM and sounds the same for voice.")
                    }
                }

                Section {
                    VStack(alignment: .leading) {
                        LabeledContent("Input Gain") {
                            Text(verbatim: String(format: "%+.0f dB", settings.inputGainDB))
                                .monospacedDigit()
                        }
                        Slider(
                            value: Binding(get: { settings.inputGainDB }, set: { model.setInputGain($0.rounded()) }),
                            in: 0...24,
                            step: 1
                        ) {
                            Text("Input Gain")
                        } minimumValueLabel: {
                            Image(systemName: "speaker.wave.1")
                        } maximumValueLabel: {
                            Image(systemName: "speaker.wave.3")
                        }
                    }
                } header: {
                    Text("Microphone")
                } footer: {
                    Text("Takes effect right away. A limiter keeps loud sounds from clipping.")
                }

                Section {
                    Toggle("Voice Processing", isOn: $settings.voiceProcessing)
                } footer: {
                    Text("Uses the system echo cancellation, noise suppression and automatic gain. Good for calls and meetings, turn it off for music.")
                }

                Section {
                    Toggle("Keep Screen On", isOn: $settings.keepScreenOn)
                    Toggle("Live Activity", isOn: $settings.liveActivity)
                } header: {
                    Text("General")
                } footer: {
                    Text("Live Activity shows the connection and mute controls on the Lock Screen and in the Dynamic Island.")
                }

                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("About", systemImage: "info.circle")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func rateLabel(_ rate: Int) -> String {
        rate % 1000 == 0 ? "\(rate / 1000) kHz" : String(format: "%.1f kHz", Double(rate) / 1000)
    }
}

struct AboutView: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Version", value: version)
                LabeledContent("Protocol", value: "MicYou 2.x")
                LabeledContent("Default Port", value: String(MicYouWire.defaultPort))
            }
            Section {
                Link(destination: URL(string: "https://github.com/MicYou-Dev/MicYou")!) {
                    Label("MicYou Desktop", systemImage: "desktopcomputer")
                }
                Link(destination: URL(string: "https://github.com/MicYou-Dev/MicYou-iOS")!) {
                    Label("Source Code", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                Link(destination: URL(string: "https://www.gnu.org/licenses/gpl-3.0.html")!) {
                    Label("GNU General Public License v3.0", systemImage: "doc.text")
                }
            } footer: {
                Text("MicYou for iOS is free software released under the GPL 3.0 or later. Its protocol implementation is ported from MicYou by LanRhyme and contributors.")
            }
        }
        .navigationTitle("About")
    }
}
