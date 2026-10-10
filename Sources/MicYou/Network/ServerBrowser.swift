// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import MicYouProtocol
import Network
import Observation
import os

struct DiscoveredServer: Identifiable, Hashable, Sendable {
    /// Bonjour instance name, for example "MicYou (DESKTOP-1234)"
    let name: String
    let endpoint: NWEndpoint

    var id: String { name }

    /// The host name inside the instance name, the desktop registers "MicYou (<hostname>)"
    var displayName: String {
        if name.hasPrefix("MicYou ("), name.hasSuffix(")") {
            return String(name.dropFirst("MicYou (".count).dropLast())
        }
        return name
    }
}

/// Browses for desktops advertising `_micyou._tcp`
@MainActor @Observable
final class ServerBrowser {
    enum State: Equatable {
        case idle
        case searching
        case denied
        case failed(String)
    }

    private(set) var servers: [DiscoveredServer] = []
    private(set) var state: State = .idle

    @ObservationIgnored private var browser: NWBrowser?
    @ObservationIgnored private let log = Logger(subsystem: "com.chouchiu.micyou", category: "browser")

    func start() {
        guard browser == nil else { return }
        let parameters = NWParameters()
        parameters.includePeerToPeer = false
        let browser = NWBrowser(for: .bonjour(type: MicYouWire.bonjourServiceType, domain: nil), using: parameters)
        browser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in self?.update(state) }
        }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            let servers = results.compactMap { result -> DiscoveredServer? in
                guard case .service(let name, _, _, _) = result.endpoint else { return nil }
                return DiscoveredServer(name: name, endpoint: result.endpoint)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            Task { @MainActor in self?.servers = servers }
        }
        browser.start(queue: .main)
        self.browser = browser
        state = .searching
    }

    func stop() {
        browser?.cancel()
        browser = nil
        state = .idle
    }

    func restart() {
        stop()
        servers = []
        start()
    }

    private func update(_ newState: NWBrowser.State) {
        switch newState {
        case .ready, .setup:
            state = .searching
        case .waiting(let error), .failed(let error):
            log.error("Browser: \(error.localizedDescription)")
            if case .dns(let code) = error, code == -65570 /* kDNSServiceErr_PolicyDenied */ {
                state = .denied
            } else {
                state = .failed(error.localizedDescription)
            }
        case .cancelled:
            state = .idle
        @unknown default:
            break
        }
    }
}
