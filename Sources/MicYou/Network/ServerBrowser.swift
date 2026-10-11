// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import MicYouCore
import MicYouProtocol
import Network
import Observation
import os

struct DiscoveredServer: Identifiable, Hashable, Sendable {
    /// Bonjour instance name, for example "MicYou (DESKTOP-1234)"
    let name: String
    let endpoint: NWEndpoint

    var id: String { name }

    var displayName: String { Self.displayName(for: name) }

    static func displayName(for name: String) -> String {
        ServiceName.displayName(name)
    }

    /// A Bonjour endpoint for an instance name, resolved when a connection starts
    /// rather than taken from the browse results, which take a moment after launch
    static func endpoint(for name: String) -> NWEndpoint {
        .service(name: name, type: MicYouWire.bonjourServiceType, domain: "local.", interface: nil)
    }
}

/// Browses for desktops advertising `_micyou._tcp`
@MainActor @Observable
final class ServerBrowser {
    enum State: Equatable {
        case idle
        case searching
        case denied
        /// The host app does not declare `_micyou._tcp` in NSBonjourServices, as inside LiveContainer
        case unavailable
        case failed(String)
    }

    private(set) var servers: [DiscoveredServer] = []
    private(set) var state: State = .idle

    @ObservationIgnored private var browser: NWBrowser?
    @ObservationIgnored private let log = Logger.micyou("browser")

    func start() {
        guard browser == nil else { return }
        let parameters = NWParameters()
        parameters.includePeerToPeer = false
        let browser = NWBrowser(for: .bonjour(type: MicYouWire.bonjourServiceType, domain: nil), using: parameters)
        // Started on the main queue, so handlers apply in order without hopping through tasks
        browser.stateUpdateHandler = { [weak self] state in
            MainActor.assumeIsolated { self?.update(state) }
        }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            let servers = results.compactMap { result -> DiscoveredServer? in
                guard case .service(let name, _, _, _) = result.endpoint else { return nil }
                return DiscoveredServer(name: name, endpoint: result.endpoint)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            MainActor.assumeIsolated { self?.servers = servers }
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
            log.error("Browsing failed: \(String(describing: error), privacy: .public)")
            switch error {
            case .dns(-65570 /* kDNSServiceErr_PolicyDenied */):
                state = .denied
            case .dns(-65555 /* kDNSServiceErr_NoAuth */):
                state = .unavailable
            default:
                state = .failed(error.localizedDescription)
            }
        case .cancelled:
            state = .idle
        @unknown default:
            break
        }
    }
}
