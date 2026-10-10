// SPDX-License-Identifier: GPL-3.0-or-later
// Wire constants of the MicYou protocol, mirrored from MicYou-Dev/MicYou

import Foundation

public enum MicYouWire {
    /// Raw ASCII sent by the client right after the TCP connection opens
    public static let handshakeClient = Data("MicYouCheck1".utf8)
    /// Raw ASCII the desktop answers with
    public static let handshakeServer = Data("MicYouCheck2".utf8)

    /// "MicY", prefixes every TCP frame
    public static let tcpMagic: UInt32 = 0x4D69_6359
    /// "MicU", prefixes every UDP datagram
    public static let udpMagic: UInt32 = 0x4D69_6355
    public static let headerSize = 8

    public static let maxControlPayload = 1024 * 1024
    public static let udpMaxDatagram = 1472
    /// Largest raw PCM chunk that still fits a UDP datagram with header and FEC metadata
    public static let udpPCMPayload = 1320

    public static let defaultPort: UInt16 = 8554
    /// Audio datagrams go to the TCP port plus this offset
    public static let udpPortOffset: UInt16 = 1
    public static let bonjourServiceType = "_micyou._tcp"

    /// The desktop pings every 500 ms, silence for this long means it is gone
    public static let heartbeatTimeout: TimeInterval = 5
    public static let handshakeTimeout: TimeInterval = 5
    public static let fecGroupSize = 12

    public static func udpPort(forTCPPort port: UInt16) -> UInt16 {
        port == UInt16.max ? port : port + udpPortOffset
    }
}

/// Value of `AudioPacketMessage.codec`
public enum AudioCodec: Int32, Sendable, CaseIterable {
    case pcm = 0
    case opus = 1
}

/// Value of `AudioPacketMessage.audioFormat`, uses Android `AudioFormat` encoding constants
public enum WireAudioFormat: Int32, Sendable {
    case pcm16 = 2
    case pcm8 = 3
    case float32 = 4
    case pcm24 = 6

    public var bytesPerSample: Int {
        switch self {
        case .pcm16: 2
        case .pcm8: 1
        case .float32: 4
        case .pcm24: 3
        }
    }
}
