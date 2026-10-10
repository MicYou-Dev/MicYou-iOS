// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// A desktop typed in by hand, host plus TCP port
public struct ServerAddress: Equatable, Sendable {
    public var host: String
    public var port: UInt16

    public init(host: String, port: UInt16) {
        self.host = host
        self.port = port
    }

    /// Parses "192.168.1.5", "192.168.1.5:8554", "fe80::1" or "[fe80::1]:8554"
    /// A port in the text wins over `defaultPort`, nil when the host is empty or a port is out of range
    public init?(parsing text: String, defaultPort: Int = Int(MicYouWire.defaultPort)) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var host = text
        var port = defaultPort
        if text.hasPrefix("["), let close = text.firstIndex(of: "]") {
            host = String(text[text.index(after: text.startIndex)..<close])
            let rest = text[text.index(after: close)...]
            if rest.hasPrefix(":") {
                guard let typed = Int(rest.dropFirst()) else { return nil }
                port = typed
            } else if !rest.isEmpty {
                return nil
            }
        } else if text.count(where: { $0 == ":" }) == 1, let colon = text.firstIndex(of: ":") {
            // More than one colon is a bare IPv6 address
            guard let typed = Int(text[text.index(after: colon)...]) else { return nil }
            host = String(text[..<colon])
            port = typed
        }
        guard !host.isEmpty, let port = UInt16(exactly: port), port > 0 else { return nil }
        self.init(host: host, port: port)
    }
}
