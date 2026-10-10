// SPDX-License-Identifier: GPL-3.0-or-later

import MicYouProtocol
import Network

enum TransportMode: String, CaseIterable, Identifiable, Sendable {
    /// Control over TCP, audio over UDP, the desktop default
    case tcpUDP
    /// Everything over the TCP connection
    case tcp

    var id: Self { self }
}

enum CodecChoice: String, CaseIterable, Identifiable, Sendable {
    case opus
    case pcm

    var id: Self { self }

    var wire: AudioCodec {
        switch self {
        case .opus: .opus
        case .pcm: .pcm
        }
    }

    /// Opus has no 44.1 kHz mode and sends anything it cannot run at as 48 kHz
    func streamRate(forCaptureRate rate: Int) -> Int {
        self == .opus ? Int(OpusEncoder.opusRate(for: Double(rate))) : rate
    }
}

/// One tap combinations of the connection and audio settings, channels and FEC stay as they are
enum StreamPreset: CaseIterable, Identifiable {
    case lowLatency
    case stable
    case lossless

    var id: Self { self }

    var transport: TransportMode {
        self == .stable ? .tcp : .tcpUDP
    }

    var codec: CodecChoice {
        self == .lossless ? .pcm : .opus
    }

    var opusBitrate: Int {
        self == .stable ? 96000 : 64000
    }

    var sampleRate: Int { 48000 }
}

/// Everything one stream needs, frozen when it starts so settings edits only apply to the next one
struct StreamConfig: Sendable {
    var endpoint: NWEndpoint
    /// Bonjour results resolve to both families, the desktop listens on IPv4
    var preferIPv4: Bool
    var transport: TransportMode
    var codec: CodecChoice
    var sampleRate: Int
    var channels: Int
    var opusBitrate: Int
    var fecEnabled: Bool

    /// The format asked for, the session falls back to PCM when Opus is unavailable
    var requestedFormat: AudioStreamFormat {
        AudioStreamFormat(sampleRate: Int32(sampleRate), channelCount: Int32(channels), codec: codec.wire)
    }
}
