// SPDX-License-Identifier: GPL-3.0-or-later

/// Whether the phone can reach a computer on the local network, judged from the current network path
public enum NetworkStatus: Equatable, Sendable {
    case local
    /// Only a cellular connection, a computer on the local network is out of reach
    case cellularOnly
    case offline

    /// Wi-Fi and Ethernet count as local, so do other interfaces such as a VPN that may reach the computer over cellular
    public init(satisfied: Bool, wifi: Bool, wired: Bool, other: Bool) {
        if !satisfied {
            self = .offline
        } else if wifi || wired || other {
            self = .local
        } else {
            self = .cellularOnly
        }
    }

    /// USB connects through the cable and needs no network
    public func needsWarning(overUSB: Bool) -> Bool {
        !overUSB && self != .local
    }
}
