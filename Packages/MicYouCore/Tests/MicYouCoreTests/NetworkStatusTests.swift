// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
@testable import MicYouCore

@Suite struct Network {
    @Test func classifiesPaths() {
        #expect(NetworkStatus(satisfied: true, wifi: true, wired: false, other: false) == .local)
        #expect(NetworkStatus(satisfied: true, wifi: false, wired: true, other: false) == .local)
        // A VPN such as Tailscale over cellular
        #expect(NetworkStatus(satisfied: true, wifi: false, wired: false, other: true) == .local)
        #expect(NetworkStatus(satisfied: true, wifi: false, wired: false, other: false) == .cellularOnly)
        #expect(NetworkStatus(satisfied: false, wifi: true, wired: false, other: false) == .offline)
    }

    @Test func usbNeedsNoNetwork() {
        #expect(NetworkStatus.cellularOnly.needsWarning(overUSB: false))
        #expect(NetworkStatus.offline.needsWarning(overUSB: false))
        #expect(!NetworkStatus.offline.needsWarning(overUSB: true))
        #expect(!NetworkStatus.local.needsWarning(overUSB: false))
    }
}
