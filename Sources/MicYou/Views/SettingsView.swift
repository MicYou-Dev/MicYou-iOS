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
                        Label("Changes apply the next time you connect.", systemImage: "info.circle")
                            .font(.footnote)
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
                    Text("TCP + UDP has the lowest latency. Use TCP Only on networks that drop UDP.")
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
                        Text("Opus needs far less bandwidth than PCM with no audible loss for voice.")
                    }
                }

                Section {
                    Toggle("Voice Processing", isOn: $settings.voiceProcessing)
                } footer: {
                    Text("Uses the system echo cancellation and noise suppression. Best for calls and meetings, turn off for music or recording.")
                }

                Section("General") {
                    Toggle("Keep Screen On", isOn: $settings.keepScreenOn)
                    Toggle("Live Activity", isOn: $settings.liveActivity)
                }

                Section {
                    NavigationLink("About") { AboutView() }
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
