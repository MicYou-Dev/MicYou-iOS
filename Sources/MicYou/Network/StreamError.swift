// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import MicYouShared
import Network

enum StreamError: LocalizedError, Equatable {
    /// Fallback for network errors without a friendlier message, carries the system description
    case unreachable(String)
    case refused
    case hostUnreachable
    /// The name did not resolve, the computer is off, asleep or on another network
    case notFound
    case localNetworkDenied
    case connectTimeout
    case handshakeFailed
    case heartbeatTimeout
    case closedByPeer
    case protocolError(String)
    case noPeerAddress
    case udpFailed
    /// The desktop never connected through usbmuxd
    case usbTimeout

    var errorDescription: String? {
        switch self {
        case .unreachable(let reason): L10n.Failure.unreachable(reason)
        case .refused: L10n.Failure.refused
        case .hostUnreachable: L10n.Failure.hostUnreachable
        case .notFound: L10n.Failure.notFound
        case .localNetworkDenied: L10n.Home.localNetworkDenied
        case .connectTimeout: L10n.Failure.timeout
        case .handshakeFailed: L10n.Failure.handshake
        case .heartbeatTimeout: L10n.Failure.heartbeat
        case .closedByPeer: L10n.Failure.closedByPeer
        case .protocolError(let detail): L10n.Failure.unexpectedData(detail)
        case .noPeerAddress: L10n.Failure.noPeerAddress
        case .udpFailed: L10n.Failure.udpFailed
        case .usbTimeout: L10n.Failure.usbTimeout
        }
    }

    /// Errors worth retrying automatically, a wrong port, an old desktop or a denied permission will not fix itself
    var isTransient: Bool {
        switch self {
        case .handshakeFailed, .protocolError, .localNetworkDenied: false
        default: true
        }
    }

    static func from(_ error: NWError) -> StreamError {
        if case .dns(let code) = error {
            return code == -65570 /* kDNSServiceErr_PolicyDenied */ ? .localNetworkDenied : .notFound
        }
        guard case .posix(let code) = error else { return .unreachable(error.localizedDescription) }
        switch code {
        case .ECONNRESET, .EPIPE, .ENOTCONN: return .closedByPeer
        case .ECONNREFUSED: return .refused
        case .EHOSTUNREACH, .ENETUNREACH, .EHOSTDOWN, .ENETDOWN: return .hostUnreachable
        case .ETIMEDOUT: return .connectTimeout
        default: return .unreachable(error.localizedDescription)
        }
    }
}
