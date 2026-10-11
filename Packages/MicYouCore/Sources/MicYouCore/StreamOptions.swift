// SPDX-License-Identifier: GPL-3.0-or-later

import MicYouProtocol

public enum TransportMode: String, CaseIterable, Identifiable, Sendable {
    /// Control over TCP, audio over UDP, the desktop default
    case tcpUDP
    /// Everything over the TCP connection
    case tcp

    public var id: Self { self }
}

public enum CodecChoice: String, CaseIterable, Identifiable, Sendable {
    case opus
    case pcm

    public var id: Self { self }

    public var wire: AudioCodec {
        switch self {
        case .opus: .opus
        case .pcm: .pcm
        }
    }

    /// Opus has no 44.1 kHz mode and sends anything it cannot run at as 48 kHz
    public func streamRate(forCaptureRate rate: Int) -> Int {
        self == .opus ? OpusRates.streamRate(forCaptureRate: rate) : rate
    }
}

public enum OpusRates {
    /// Opus only runs at these rates, the desktop decoder accepts the same set
    public static let supported = [48000, 24000, 16000, 12000, 8000]

    /// Keeps a supported capture rate and sends anything else at 48 kHz, so 44.1 kHz maps to 48 kHz like on Android
    public static func streamRate(forCaptureRate rate: Int) -> Int {
        supported.contains(rate) ? rate : 48000
    }
}

/// One tap combinations of the connection and audio settings, channels and FEC stay as they are
public enum StreamPreset: CaseIterable, Identifiable, Sendable {
    case lowLatency
    case stable
    case lossless

    public var id: Self { self }

    public var transport: TransportMode {
        self == .stable ? .tcp : .tcpUDP
    }

    public var codec: CodecChoice {
        self == .lossless ? .pcm : .opus
    }

    public var opusBitrate: Int {
        self == .stable ? 96000 : 64000
    }

    public var sampleRate: Int { 48000 }

    /// The preset these choices match, nil once something was changed by hand
    /// The bitrate only counts for Opus, PCM ignores it
    public static func matching(transport: TransportMode, codec: CodecChoice, sampleRate: Int, opusBitrate: Int) -> StreamPreset? {
        allCases.first { preset in
            transport == preset.transport && codec == preset.codec && sampleRate == preset.sampleRate
                && (codec == .pcm || opusBitrate == preset.opusBitrate)
        }
    }
}

/// The audio and transport choices of one stream, frozen when it starts
public struct StreamOptions: Equatable, Sendable {
    public var transport: TransportMode
    public var codec: CodecChoice
    /// The rate actually sent, already mapped to one Opus supports
    public var sampleRate: Int
    public var channels: Int
    public var opusBitrate: Int
    public var fecEnabled: Bool

    public init(transport: TransportMode, codec: CodecChoice, sampleRate: Int, channels: Int, opusBitrate: Int, fecEnabled: Bool) {
        self.transport = transport
        self.codec = codec
        self.sampleRate = sampleRate
        self.channels = channels
        self.opusBitrate = opusBitrate
        self.fecEnabled = fecEnabled
    }

    /// FEC only exists for UDP audio
    public var usesFEC: Bool { fecEnabled && transport == .tcpUDP }

    /// The format asked for, the session falls back to PCM when Opus is unavailable
    public var requestedFormat: AudioStreamFormat {
        AudioStreamFormat(sampleRate: Int32(sampleRate), channelCount: Int32(channels), codec: codec.wire)
    }

    /// Audio bits per second without packet headers, the parity packets of FEC included
    public var estimatedBitrate: Int {
        let audio = codec == .opus ? opusBitrate : sampleRate * 16 * channels
        return usesFEC ? audio * (MicYouWire.fecGroupSize + 1) / MicYouWire.fecGroupSize : audio
    }

    /// For logs and reports, always English: "Opus 64 kbps, 48000 Hz mono, UDP with FEC"
    public var summary: String {
        let codec = codec == .opus ? "Opus \(opusBitrate / 1000) kbps" : "PCM"
        let transport = transport == .tcp ? "TCP only" : usesFEC ? "UDP with FEC" : "UDP"
        return "\(codec), \(sampleRate) Hz \(channels == 2 ? "stereo" : "mono"), \(transport)"
    }

    /// Whether a running stream would look different with `other`, choices that cannot take effect do not count
    public func differs(from other: StreamOptions) -> Bool {
        transport != other.transport || codec != other.codec || sampleRate != other.sampleRate
            || channels != other.channels || usesFEC != other.usesFEC
            || (codec == .opus && opusBitrate != other.opusBitrate)
    }
}
