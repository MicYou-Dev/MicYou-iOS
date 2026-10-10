// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
@testable import MicYouProtocol

@Suite struct Addresses {
    @Test func hostUsesDefaultPort() {
        #expect(ServerAddress(parsing: " 192.168.1.5 ", defaultPort: 9000) == ServerAddress(host: "192.168.1.5", port: 9000))
        #expect(ServerAddress(parsing: "desktop.local") == ServerAddress(host: "desktop.local", port: MicYouWire.defaultPort))
    }

    @Test func typedPortWins() {
        #expect(ServerAddress(parsing: "192.168.1.5:7000", defaultPort: 9000) == ServerAddress(host: "192.168.1.5", port: 7000))
        #expect(ServerAddress(parsing: "[fe80::1]:7000") == ServerAddress(host: "fe80::1", port: 7000))
    }

    @Test func bareIPv6KeepsAllColons() {
        #expect(ServerAddress(parsing: "fe80::1") == ServerAddress(host: "fe80::1", port: MicYouWire.defaultPort))
        #expect(ServerAddress(parsing: "[fe80::1]") == ServerAddress(host: "fe80::1", port: MicYouWire.defaultPort))
    }

    @Test(arguments: ["", "   ", ":8554", "host:", "host:abc", "host:0", "host:65536", "[fe80::1]x", "[fe80::1]:"])
    func rejectsUnusableInput(_ text: String) {
        #expect(ServerAddress(parsing: text) == nil)
    }

    @Test func rejectsOutOfRangeDefaultPort() {
        #expect(ServerAddress(parsing: "host", defaultPort: 70000) == nil)
        #expect(ServerAddress(parsing: "host", defaultPort: 0) == nil)
    }
}
