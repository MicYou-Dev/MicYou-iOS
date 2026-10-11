// SPDX-License-Identifier: GPL-3.0-or-later

import MicYouCore
import Network

/// Everything one stream needs, frozen when it starts so settings edits only apply to the next one
/// The audio and transport choices live in `options`, readable directly as `config.codec` and so on
@dynamicMemberLookup
struct StreamConfig: Sendable {
    var endpoint: NWEndpoint
    /// Bonjour results resolve to both families, the desktop listens on IPv4
    var preferIPv4: Bool
    var options: StreamOptions

    subscript<Value>(dynamicMember keyPath: KeyPath<StreamOptions, Value>) -> Value {
        options[keyPath: keyPath]
    }
}
