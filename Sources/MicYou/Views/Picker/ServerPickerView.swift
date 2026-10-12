// SPDX-License-Identifier: GPL-3.0-or-later

import MicYouProtocol
import MicYouShared
import SwiftUI

/// Sheet for picking a nearby computer, the USB cable, a recent address or typing a new one
struct ServerPickerView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focus: ManualField?
    /// The address or port was typed into since the sheet opened or a row was picked
    @State private var editedManual = false

    var body: some View {
        NavigationStack {
            List {
                NearbySection(pick: pick)
                USBSection(pick: pick)
                ManualSection(focus: $focus, pick: pick)
                RecentSection(pick: pick)
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
            .onChange(of: settings.host) { editedManual = true }
            .onChange(of: settings.port) { editedManual = true }
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
        // Closing the sheet after typing an address uses it, as Use Address would
        .onDisappear {
            if editedManual && settings.manualTarget != nil { model.selection = .manual }
        }
    }

    private func pick(_ selection: ServerSelection) {
        model.selection = selection
        editedManual = false
        dismiss()
    }
}

/// A choice in the list, checked while it is the current selection
private struct ChoiceRow: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 28)
                Text(title)
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(.tint)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct NearbySection: View {
    @Environment(AppModel.self) private var model
    let pick: (ServerSelection) -> Void

    var body: some View {
        Section {
            ForEach(model.browser.servers) { server in
                let selection = ServerSelection.discovered(name: server.name)
                ChoiceRow(title: server.displayName, systemImage: "desktopcomputer", isSelected: model.selection == selection) {
                    pick(selection)
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
    let pick: (ServerSelection) -> Void

    var body: some View {
        Section {
            ChoiceRow(title: L10n.Home.usbName, systemImage: "cable.connector", isSelected: model.selection == .usb) {
                pick(.usb)
            }
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
    let pick: (ServerSelection) -> Void

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
            Button {
                pick(.manual)
            } label: {
                HStack {
                    Text(L10n.Home.useAddress)
                    Spacer()
                    // A remembered address carries the check in the recent list instead
                    if isSelected && !settings.recentHosts.contains(settings.typedHost) {
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

    private var isSelected: Bool {
        model.selection == .manual && settings.manualTarget != nil
    }
}

/// Addresses used before, tapping one uses it again and swiping removes it
private struct RecentSection: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    let pick: (ServerSelection) -> Void

    var body: some View {
        if !settings.recentHosts.isEmpty {
            Section(L10n.Home.recentAddresses) {
                ForEach(settings.recentHosts, id: \.self) { host in
                    ChoiceRow(title: host, systemImage: "network", isSelected: model.selection == .manual && settings.typedHost == host) {
                        settings.host = host
                        pick(.manual)
                    }
                }
                .onDelete(perform: settings.forgetHosts)
            }
        }
    }
}
