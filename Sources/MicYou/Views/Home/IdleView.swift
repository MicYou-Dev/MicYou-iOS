// SPDX-License-Identifier: GPL-3.0-or-later

import MicYouCore
import MicYouShared
import SwiftUI

/// The computer to use, the connect button and the format that will be sent
struct IdleView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var shownRelease: AppRelease?
    let openPicker: () -> Void
    let openSettings: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            TargetCard(action: openPicker)
                .tourTarget(.computer)
            if case .failed(let message) = model.phase {
                NoticeCard(title: L10n.Status.failed, text: message, kind: .error) {
                    withAnimation(Motion.state) { model.clearError() }
                }
                .adaptiveTransition(.notice)
            } else if let notice = model.notice {
                NoticeCard(text: notice, kind: .info) {
                    withAnimation(Motion.state) { model.notice = nil }
                }
                .adaptiveTransition(.notice)
            } else if model.showsNetworkWarning {
                NoticeCard(
                    title: model.network.status == .offline ? L10n.Home.offline : L10n.Home.notOnWiFi,
                    text: L10n.Home.networkText, kind: .info,
                    action: (L10n.Home.useUSB, { withAnimation(Motion.state) { model.selection = .usb } })
                ) {
                    withAnimation(Motion.state) { model.network.dismissWarning() }
                }
                .adaptiveTransition(.notice)
            } else if let release = model.updates.notice {
                NoticeCard(
                    title: L10n.Home.updateTitle(release.version.description), text: L10n.Home.updateText, kind: .info,
                    action: (L10n.Home.viewUpdate, { view(release) })
                ) {
                    withAnimation(Motion.state) { model.updates.dismissNotice() }
                }
                .adaptiveTransition(.notice)
            }
            Spacer(minLength: 16)
            VStack(spacing: 24) {
                HeroButton(title: heroTitle, systemImage: heroSymbol, isProminent: model.canConnect, action: heroAction)
                    .tourTarget(.connect)
                // Kept in the layout while hidden so the button does not shift
                Text(L10n.Home.hint)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .opacity(showsHint ? 1 : 0)
                    .accessibilityHidden(!showsHint)
            }
            Spacer(minLength: 16)
            FormatSummary(action: openSettings)
        }
        .animation(Motion.state, value: model.phase)
        .animation(Motion.state, value: model.canConnect)
        .animation(Motion.state, value: model.notice)
        .animation(Motion.state, value: model.showsNetworkWarning)
        .animation(Motion.state, value: model.updates.notice)
        .releaseNotesSheet($shownRelease)
    }

    private func view(_ release: AppRelease) {
        if release.notes != nil { shownRelease = release } else { openURL(release.page) }
    }

    private var isFailed: Bool {
        if case .failed = model.phase { true } else { false }
    }

    private var showsHint: Bool { model.canConnect && !isFailed }

    private var heroTitle: String {
        !model.canConnect ? L10n.Home.chooseComputer : isFailed ? L10n.Common.retry : L10n.Common.connect
    }

    private var heroSymbol: String {
        !model.canConnect ? "desktopcomputer" : isFailed ? "arrow.clockwise" : "mic.fill"
    }

    private func heroAction() {
        if model.canConnect { model.toggleConnection() } else { openPicker() }
    }
}

/// The large round button in the middle of the idle screen
private struct HeroButton: View {
    let title: String
    let systemImage: String
    /// Tinted when it connects, plain glass when it only opens the picker
    let isProminent: Bool
    let action: () -> Void
    /// Grows with Dynamic Type so the title keeps room, capped to stay on screen
    @ScaledMetric(relativeTo: .title3) private var diameter: CGFloat = 184

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 40, weight: .medium))
                    .contentTransition(.symbolEffect(.replace.magic(fallback: .replace)))
                Text(title)
                    .contentTransition(.opacity)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
            .frame(width: min(diameter, 260), height: min(diameter, 260))
            .foregroundStyle(isProminent ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .glassSurface(in: .circle, tint: isProminent ? .accentColor : nil)
            .contentShape(.circle)
        }
        .buttonStyle(.surface)
    }
}

/// Shows where the next stream goes, tapping it opens the picker
private struct TargetCard: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .background(.fill.tertiary, in: .rect(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.Home.targetLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)
                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                HStack(spacing: 2) {
                    Text(L10n.Home.change)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassSurface(in: .rect(cornerRadius: 22, style: .continuous))
            .contentShape(.rect(cornerRadius: 22))
            // Bonjour results arrive outside any transaction, fade the line instead of snapping
            .contentTransition(.opacity)
            .adaptiveAnimation(value: subtitle)
            .adaptiveAnimation(value: title)
        }
        .buttonStyle(.surface)
        // Long press switches between nearby and recent computers without opening the picker
        .contextMenu { quickSwitch }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.canConnect ? L10n.Status.ready(title) : title)
        .accessibilityValue(subtitle ?? "")
        .accessibilityHint(L10n.Home.chooseComputer)
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var quickSwitch: some View {
        if !model.browser.servers.isEmpty {
            Section(L10n.Home.nearbyHeader) {
                ForEach(model.browser.servers) { server in
                    Toggle(isOn: Binding(
                        get: { model.selection == .discovered(name: server.name) },
                        set: { _ in model.selection = .discovered(name: server.name) }
                    )) {
                        Label(server.displayName, systemImage: "desktopcomputer")
                    }
                }
            }
        }
        if !settings.recentHosts.isEmpty {
            Section(L10n.Home.recentAddresses) {
                ForEach(settings.recentHosts, id: \.self) { host in
                    Toggle(isOn: Binding(
                        get: { model.selection == .manual && settings.host == host },
                        set: { _ in
                            settings.host = host
                            model.selection = .manual
                        }
                    )) {
                        Label(host, systemImage: "network")
                    }
                }
            }
        }
        Toggle(isOn: Binding(get: { model.selection == .usb }, set: { _ in model.selection = .usb })) {
            Label(L10n.Home.usbName, systemImage: "cable.connector")
        }
        Button(L10n.Home.chooseComputer, systemImage: "ellipsis.circle", action: action)
    }

    private var symbol: String {
        switch model.selection {
        case .discovered: "desktopcomputer"
        case .manual: "network"
        case .usb: "cable.connector"
        }
    }

    private var title: String {
        switch model.selection {
        case .discovered(let name):
            // A remembered computer keeps its name while the search is still running
            return ServiceName.displayName(name)
        case .manual:
            return settings.manualTarget?.host ?? L10n.Home.noTarget
        case .usb:
            return L10n.Home.usbName
        }
    }

    private var subtitle: String? {
        switch model.selection {
        case .discovered(let name):
            return model.browser.servers.contains { $0.name == name } ? L10n.Home.nearbyHeader : L10n.Home.searching
        case .manual:
            guard let target = settings.manualTarget else { return nil }
            return L10n.Common.joined([L10n.Home.manualHeader, "\(L10n.Home.port) \(target.port)"])
        case .usb:
            return L10n.Home.usbSubtitle
        }
    }
}

/// Codec, sample rate and transport for the next stream, tapping it opens the settings
private struct FormatSummary: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.Home.formatHeader)
                Spacer()
                Button(L10n.Home.adjust, action: action)
                    .buttonStyle(.borderless)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            Button(action: action) {
                HStack(spacing: 0) {
                    tile(codec, codecDetail)
                    Divider()
                    tile(L10n.Unit.kHz(sampleRate), StreamText.channels(settings.stereo ? 2 : 1))
                    Divider()
                    tile(transport, transportDetail)
                }
                // Vertical dividers take all the height offered, keep the row at the height of its text
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 12)
                .glassSurface(in: .rect(cornerRadius: 22, style: .continuous))
                .contentShape(.rect(cornerRadius: 22))
            }
            .buttonStyle(.surface)
            .tourTarget(.format)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L10n.Home.formatHeader)
            .accessibilityValue(L10n.Common.joined([codec, codecDetail, L10n.Unit.kHz(sampleRate), transport, transportDetail]))
            .accessibilityHint(L10n.Common.settings)
            .accessibilityAddTraits(.isButton)
        }
    }

    private func tile(_ value: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.subheadline.weight(.semibold))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .monospacedDigit()
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sampleRate: Int { settings.streamSampleRate }

    private var codec: String { settings.codec.shortName }

    /// PCM shows its raw 16 bit rate so the bandwidth difference is visible
    private var codecDetail: String {
        let bitrate = settings.codec == .opus ? settings.opusBitrate : sampleRate * 16 * (settings.stereo ? 2 : 1)
        return L10n.Unit.kbps(bitrate / 1000)
    }

    /// USB only carries TCP, whatever the transport setting says
    private var transport: String {
        model.selection == .usb ? TransportMode.tcp.shortName : settings.transport.shortName
    }

    private var transportDetail: String {
        if model.selection == .usb { return L10n.Home.usbName }
        return switch settings.transport {
        case .tcpUDP: settings.fecEnabled ? L10n.Status.fec : settings.transport.title
        case .tcp: settings.transport.title
        }
    }
}
