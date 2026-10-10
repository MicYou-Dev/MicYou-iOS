// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import MicYouShared
import Network

enum StreamError: LocalizedError, Equatable {
    case unreachable(String)
    case connectTimeout
    case handshakeFailed
    case heartbeatTimeout
    case closedByPeer
    case protocolError(String)
    case noPeerAddress
    case udpFailed
    case capture(String)

    var errorDescription: String? {
        switch self {
        case .unreachable(let reason):
            L10n.Failure.unreachable(reason)
        case .connectTimeout:
            L10n.Failure.timeout
        case .handshakeFailed:
            L10n.Failure.handshake
        case .heartbeatTimeout:
            L10n.Failure.heartbeat
        case .closedByPeer:
            L10n.Failure.closedByPeer
        case .protocolError(let detail):
            L10n.Failure.unexpectedData(detail)
        case .noPeerAddress:
            L10n.Failure.noPeerAddress
        case .udpFailed:
            L10n.Failure.udpFailed
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
