// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    StatusView()
                }
                if case .failed(let message) = model.phase {
                    Section {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .symbolRenderingMode(.multicolor)
                    }
                }
                if let notice = model.notice {
                    Section {
                        Label(notice, systemImage: "info.circle")
                    }
                }
                ServerListSection()
                ManualSection()
            }
            .navigationTitle("MicYou")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") { showSettings = true }
                }
            }
            .safeAreaInset(edge: .bottom) {
                ControlBar()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }
}

private struct ServerListSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Section {
            ForEach(model.browser.servers) { server in
                ServerRow(
                    title: server.displayName,
                    subtitle: server.name,
                    systemImage: "desktopcomputer",
                    isSelected: model.selection == .discovered(name: server.name)
                ) {
                    model.selection = .discovered(name: server.name)
                }
            }
            switch model.browser.state {
            case .denied:
                VStack(alignment: .leading, spacing: 8) {
                    Text("MicYou needs Local Network access to find computers.")
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            case .failed(let message):
                Text(message).foregroundStyle(.secondary)
            default:
                if model.browser.servers.isEmpty {
                    Text("Make sure MicYou is running on your computer and both devices are on the same Wi-Fi.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            HStack {
                Text("Nearby Computers")
                if model.browser.state == .searching {
                    ProgressView().controlSize(.mini).padding(.leading, 4)
                }
            }
        }
        .disabled(model.isActive)
    }
}

private struct ManualSection: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Section {
            ServerRow(
                title: String(localized: "Enter Address"),
                subtitle: nil,
                systemImage: "keyboard",
                isSelected: model.selection == .manual
            ) {
                model.selection = .manual
            }
            if model.selection == .manual {
                LabeledContent("Address") {
                    HStack {
                        TextField("192.168.1.5", text: $settings.host)
                            .keyboardType(.numbersAndPunctuation)
                            .textContentType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.trailing)
                        if !settings.recentHosts.isEmpty {
                            Menu {
                                ForEach(settings.recentHosts, id: \.self) { host in
                                    Button(host) { settings.host = host }
                                }
                            } label: {
                                Image(systemName: "clock.arrow.circlepath")
                            }
                            .accessibilityLabel("Recent Addresses")
                        }
                    }
                }
                LabeledContent("Port") {
                    TextField("8554", value: $settings.port, format: .number.grouping(.never))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }
            }
        } header: {
            Text("Manual")
        }
        .disabled(model.isActive)
    }
}

private struct ControlBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if #available(iOS 26, *) {
            // Floating Liquid Glass controls, no bar background
            GlassEffectContainer(spacing: 12) {
                buttons(muteStyle: .glass, connectStyle: .glassProminent)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        } else {
            buttons(muteStyle: .bordered, connectStyle: .borderedProminent)
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(.bar)
        }
    }

    private func buttons(muteStyle: some PrimitiveButtonStyle, connectStyle: some PrimitiveButtonStyle) -> some View {
        HStack(spacing: 12) {
            Button {
                model.toggleMute()
            } label: {
                Image(systemName: model.isMuted ? "mic.slash.fill" : "mic.fill")
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(muteStyle)
            .tint(model.isMuted ? .red : nil)
            .accessibilityLabel(model.isMuted ? Text("Unmute") : Text("Mute"))
            .sensoryFeedback(.selection, trigger: model.isMuted)

            Button {
                model.toggleConnection()
            } label: {
                Text(model.isActive ? "Disconnect" : "Connect")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 28)
            }
            .buttonStyle(connectStyle)
            .tint(model.isActive ? .red : .accentColor)
            .disabled(!model.isActive && !model.canConnect)
            .sensoryFeedback(.impact, trigger: model.isActive)
        }
        .buttonBorderShape(.capsule)
        .controlSize(.large)
    }
}
