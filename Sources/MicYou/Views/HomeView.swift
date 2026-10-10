// SPDX-License-Identifier: GPL-3.0-or-later

import MicYouProtocol
import MicYouShared
import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var showSettings = false
    @FocusState private var focus: ManualField?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    StatusView()
                }
                if let notice = model.notice {
                    NoticeSection(text: notice) {
                        withAnimation { model.notice = nil }
                    }
                }
                ServerListSection()
                ManualSection(focus: $focus)
            }
            .scrollDismissesKeyboard(.interactively)
            .refreshable {
                model.browser.restart()
                // Hold the spinner briefly so the pull reads as a fresh search
                try? await Task.sleep(for: .seconds(1))
            }
            .navigationTitle(L10n.App.name)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Common.settings, systemImage: "gearshape") { showSettings = true }
                }
                // The number pad has no return key
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(L10n.Common.done) { focus = nil }
                }
            }
            .onChange(of: model.isActive) { _, active in
                if active { focus = nil }
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

private struct NoticeSection: View {
    let text: String
    let dismiss: () -> Void

    var body: some View {
        Section {
            HStack(alignment: .firstTextBaseline) {
                Label(text, systemImage: "info.circle")
                    .font(.subheadline)
                Spacer(minLength: 8)
                Button(L10n.Common.dismiss, systemImage: "xmark", action: dismiss)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
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
                    systemImage: "desktopcomputer",
                    isSelected: model.selection == .discovered(name: server.name)
                ) {
                    model.selection = .discovered(name: server.name)
                }
            }
            switch model.browser.state {
            case .denied:
                VStack(alignment: .leading, spacing: 8) {
                    Label(L10n.Home.localNetworkDenied, systemImage: "network.slash")
                    Button(L10n.Common.openSettings) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            case .failed(let message):
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
            default:
                if model.browser.servers.isEmpty {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text(L10n.Home.searching)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text(L10n.Home.nearbyHeader)
        } footer: {
            if model.browser.servers.isEmpty && model.browser.state == .searching {
                Text(L10n.Home.searchHint)
            }
        }
        .disabled(model.isActive)
    }
}

private enum ManualField { case address, port }

private struct ManualSection: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    var focus: FocusState<ManualField?>.Binding

    var body: some View {
        @Bindable var settings = settings
        Section {
            ServerRow(
                title: L10n.Home.manualRow,
                // Shows what will be used before the row is picked
                subtitle: model.selection == .manual || settings.manualTarget == nil
                    ? nil : settings.host.trimmingCharacters(in: .whitespacesAndNewlines),
                systemImage: "keyboard",
                isSelected: model.selection == .manual
            ) {
                model.selection = .manual
            }
            if model.selection == .manual {
                LabeledContent(L10n.Home.address) {
                    HStack {
                        TextField(L10n.Home.addressPlaceholder, text: $settings.host)
                            .keyboardType(.numbersAndPunctuation)
                            .textContentType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.trailing)
                            .submitLabel(.next)
                            .focused(focus, equals: .address)
                            .onSubmit { focus.wrappedValue = .port }
                        if !settings.recentHosts.isEmpty {
                            Menu {
                                ForEach(settings.recentHosts, id: \.self) { host in
                                    Button(host) { settings.host = host }
                                }
                            } label: {
                                Image(systemName: "clock.arrow.circlepath")
                            }
                            .accessibilityLabel(L10n.Home.recentAddresses)
                        }
                    }
                }
                LabeledContent(L10n.Home.port) {
                    TextField(String(MicYouWire.defaultPort), value: $settings.port, format: .number.grouping(.never))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .focused(focus, equals: .port)
                }
            }
        } header: {
            Text(L10n.Home.manualHeader)
        } footer: {
            if model.selection == .manual {
                if settings.manualInputInvalid {
                    Text(L10n.Home.manualInvalid)
                        .foregroundStyle(.red)
                } else {
                    Text(L10n.Home.manualHint(port: Int(MicYouWire.defaultPort)))
                }
            }
        }
        .disabled(model.isActive)
    }
}
