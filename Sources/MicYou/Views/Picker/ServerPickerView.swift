// SPDX-License-Identifier: GPL-3.0-or-later

import MicYouProtocol
import MicYouShared
import SwiftUI

/// Sheet for picking a nearby computer, the USB cable or typing an address
struct ServerPickerView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focus: ManualField?

    var body: some View {
        NavigationStack {
            List {
                NearbySection {
                    dismiss()
                }
                USBSection {
                    dismiss()
                }
                ManualSection(focus: $focus) {
                    dismiss()
                }
            }
            .scrollDismissesKeyboard(.interactively)
            // Bonjour results arrive outside any transaction, slide rows in and out instead of popping
            .adaptiveAnimation(value: model.browser.servers)
            .adaptiveAnimation(value: model.browser.state)
            .adaptiveAnimation(value: model.selection)
            // Without Bonjour the address is the only way in, start there instead of leaving a grey placeholder
            .onChange(of: model.browser.state, initial: true) { _, state in
                if state == .unavailable && settings.host.isEmpty { focus = .address }
            }
            .refreshable {
                model.browser.restart()
                // Hold the spinner briefly so the pull reads as a fresh search
                try? await Task.sleep(for: .seconds(1))
            }
            .navigationTitle(L10n.Home.chooseComputer)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.done) { dismiss() }
                }
                // The number pad has no return key
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(L10n.Common.done) { focus = nil }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }
}

private struct NearbySection: View {
    @Environment(AppModel.self) private var model
    let picked: () -> Void

    var body: some View {
        Section {
            ForEach(model.browser.servers) { server in
                Button {
                    model.selection = .discovered(name: server.name)
                    picked()
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "desktopcomputer")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .frame(width: 28)
                        Text(server.displayName)
                            .foregroundStyle(.primary)
                        Spacer()
                        if model.selection == .discovered(name: server.name) {
                            Image(systemName: "checkmark")
                                .fontWeight(.semibold)
                                .foregroundStyle(.tint)
                        }
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(model.selection == .discovered(name: server.name) ? .isSelected : [])
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
            case .unavailable:
                Label(L10n.Home.browsingUnavailable, systemImage: "network.slash")
                    .foregroundStyle(.secondary)
            case .failed(let message):
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
            case .searching:
                HStack(spacing: 14) {
                    ProgressView()
                        .frame(width: 28)
                    Text(model.browser.servers.isEmpty ? L10n.Home.searching : L10n.Home.searchingMore)
                        .foregroundStyle(.secondary)
                }
            case .idle:
                EmptyView()
            }
        } header: {
            Text(L10n.Home.nearbyHeader)
        } footer: {
            if model.browser.servers.isEmpty && model.browser.state == .searching {
                Text(L10n.Home.searchHint)
            }
        }
    }
}

private struct USBSection: View {
    @Environment(AppModel.self) private var model
    let picked: () -> Void

    var body: some View {
        Section {
            Button {
                model.selection = .usb
                picked()
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "cable.connector")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 28)
                    Text(L10n.Home.usbName)
                        .foregroundStyle(.primary)
                    Spacer()
                    if model.selection == .usb {
                        Image(systemName: "checkmark")
                            .fontWeight(.semibold)
                            .foregroundStyle(.tint)
                    }
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(model.selection == .usb ? .isSelected : [])
        } header: {
            Text(L10n.Home.usbHeader)
        } footer: {
            Text(L10n.Home.usbHint)
        }
    }
}

enum ManualField { case address, port }

private struct ManualSection: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    var focus: FocusState<ManualField?>.Binding
    let picked: () -> Void

    var body: some View {
        @Bindable var settings = settings
        Section {
            LabeledContent(L10n.Home.address) {
                TextField(L10n.Home.addressPlaceholder, text: $settings.host)
                    .keyboardType(.numbersAndPunctuation)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .submitLabel(.next)
                    .focused(focus, equals: .address)
                    .onSubmit { focus.wrappedValue = .port }
            }
            LabeledContent(L10n.Home.port) {
                TextField(String(MicYouWire.defaultPort), value: $settings.port, format: .number.grouping(.never))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .focused(focus, equals: .port)
            }
            if !settings.recentHosts.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(L10n.Home.recentAddresses)
                        ForEach(settings.recentHosts, id: \.self) { host in
                            Button(host) { settings.host = host }
                                .monospacedDigit()
                                .buttonStyle(.bordered)
                                .buttonBorderShape(.capsule)
                                .controlSize(.small)
                                .tint(.primary)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
            Button {
                model.selection = .manual
                picked()
            } label: {
                HStack {
                    Text(L10n.Home.useAddress)
                    Spacer()
                    if model.selection == .manual && settings.manualTarget != nil {
                        Image(systemName: "checkmark")
                            .fontWeight(.semibold)
                    }
                }
            }
            .disabled(settings.manualTarget == nil)
        } header: {
            Text(L10n.Home.manualHeader)
        } footer: {
            if settings.manualInputInvalid {
                Text(L10n.Home.manualInvalid)
                    .foregroundStyle(.red)
            } else {
                Text(L10n.Home.manualHint(port: Int(MicYouWire.defaultPort)))
            }
        }
    }
}
