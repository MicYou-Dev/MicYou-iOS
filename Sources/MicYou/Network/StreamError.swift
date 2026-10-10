// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Network

enum StreamError: LocalizedError, Equatable {
    case unreachable(String)
    case connectTimeout
    case handshakeFailed
    case heartbeatTimeout
    case closedByPeer
    case protocolError(String)
    case udpFailed
    case capture(String)

    var errorDescription: String? {
        switch self {
        case .unreachable(let reason):
            String(localized: "Cannot reach the computer: \(reason)")
        case .connectTimeout:
            String(localized: "Connection timed out. Check that MicYou is running on the computer and both devices are on the same network.")
        case .handshakeFailed:
            String(localized: "The computer did not answer the MicYou handshake. Check the port and the desktop version.")
        case .heartbeatTimeout:
            String(localized: "Lost contact with the computer. It may be asleep or off the network.")
        case .closedByPeer:
            String(localized: "MicYou on the computer closed the connection.")
        case .protocolError(let detail):
            String(localized: "Unexpected data from the computer: \(detail)")
        case .udpFailed:
            String(localized: "Sending audio over UDP keeps failing. Switch to TCP Only in Settings.")
        case .capture(let detail):
            detail
        }
    }

    /// Errors worth retrying automatically
    var isTransient: Bool {
        switch self {
        case .handshakeFailed, .capture: false
        default: true
        }
    }

    static func from(_ error: NWError) -> StreamError {
        if case .posix(let code) = error, code == .ECONNRESET || code == .EPIPE || code == .ENOTCONN {
            return .closedByPeer
        }
        return .unreachable(error.localizedDescription)
    }
}
