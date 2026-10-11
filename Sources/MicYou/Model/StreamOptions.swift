// SPDX-License-Identifier: GPL-3.0-or-later

import MicYouCore
import Network

/// How the control connection comes about
enum StreamLink: Sendable {
    /// The phone connects to the desktop over the network
    /// Bonjour results resolve to both families, the desktop listens on IPv4
    case network(NWEndpoint, preferIPv4: Bool)
    /// The phone listens on loopback and the desktop connects through usbmuxd
    case usb(port: NWEndpoint.Port)

    var isUSB: Bool {
        if case .usb = self { true } else { false }
    }
}

/// Everything one stream needs, frozen when it starts so settings edits only apply to the next one
/// The audio and transport choices live in `options`, readable directly as `config.codec` and so on
@dynamicMemberLookup
struct StreamConfig: Sendable {
    var link: StreamLink
    var options: StreamOptions

    subscript<Value>(dynamicMember keyPath: KeyPath<StreamOptions, Value>) -> Value {
        options[keyPath: keyPath]
    }
}
