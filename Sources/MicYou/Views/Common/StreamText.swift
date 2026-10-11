// SPDX-License-Identifier: GPL-3.0-or-later

import MicYouCore
import MicYouProtocol
import MicYouShared

extension CodecChoice {
    /// "Opus" or "PCM"
    var shortName: String { wire.shortName }

    /// "PCM (Uncompressed)" spelled out for the settings picker
    var title: String {
        switch self {
        case .opus: L10n.Settings.opus
        case .pcm: L10n.Settings.pcm
        }
    }
}

extension AudioCodec {
    var shortName: String {
        switch self {
        case .opus: L10n.Settings.opus
        case .pcm: L10n.Settings.pcmShort
        }
    }
}

extension TransportMode {
    /// The channel audio travels on, "UDP" or "TCP"
    var shortName: String {
        switch self {
        case .tcpUDP: L10n.Activity.udp
        case .tcp: L10n.Activity.tcp
        }
    }

    /// "TCP + UDP" or "TCP Only"
    var title: String {
        switch self {
        case .tcpUDP: L10n.Settings.tcpUDP
        case .tcp: L10n.Settings.tcpOnly
        }
    }
}

extension StreamPreset {
    var title: String {
        switch self {
        case .lowLatency: L10n.Settings.presetLowLatency
        case .stable: L10n.Settings.presetStable
        case .lossless: L10n.Settings.presetLossless
        }
    }
}

/// Short stream descriptions shared by the home screen, the settings and the Live Activity
enum StreamText {
    /// For example "Opus 48 kHz"
    static func codecAndRate(_ format: AudioStreamFormat) -> String {
        L10n.Common.codecAndRate(format.codec.shortName, L10n.Unit.kHz(Int(format.sampleRate)))
    }

    static func channels(_ count: Int) -> String {
        count == 2 ? L10n.Common.stereo : L10n.Common.mono
    }

    /// For example "Opus 48 kHz · Stereo", mono is the norm and left out
    static func format(_ format: AudioStreamFormat) -> String {
        L10n.Common.joined([codecAndRate(format), format.channelCount == 2 ? L10n.Common.stereo : ""])
    }

    /// For example "UDP · FEC" or "TCP Only"
    static func transport(_ mode: TransportMode, fec: Bool) -> String {
        switch mode {
        case .tcpUDP: L10n.Common.joined([mode.shortName, fec ? L10n.Status.fec : ""])
        case .tcp: mode.title
        }
    }

    /// For example "Opus 64 kbps · Stereo · UDP", Opus shows its bitrate and PCM its sample rate
    static func activityDetail(_ format: AudioStreamFormat, opusBitrate: Int, transport: TransportMode) -> String {
        let codec = format.codec == .opus
            ? L10n.Common.codecAndRate(format.codec.shortName, L10n.Unit.kbps(opusBitrate / 1000))
            : codecAndRate(format)
        return L10n.Common.joined([codec, channels(Int(format.channelCount)), transport.shortName])
    }
}
