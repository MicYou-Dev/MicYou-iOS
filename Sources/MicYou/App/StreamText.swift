// SPDX-License-Identifier: GPL-3.0-or-later

import MicYouProtocol
import MicYouShared

/// Short stream descriptions shared by the status view and the Live Activity
enum StreamText {
    /// For example "Opus 48 kHz"
    static func codecAndRate(_ format: AudioStreamFormat) -> String {
        L10n.Common.codecAndRate(codecName(format.codec), L10n.Unit.kHz(Int(format.sampleRate)))
    }

    static func channels(_ format: AudioStreamFormat) -> String {
        format.channelCount == 2 ? L10n.Common.stereo : L10n.Common.mono
    }

    /// For example "Opus 64 kbps · Stereo · UDP", Opus shows its bitrate and PCM its sample rate
    static func activityDetail(_ format: AudioStreamFormat, opusBitrate: Int, transport: TransportMode) -> String {
        let codec = format.codec == .opus
            ? L10n.Common.codecAndRate(L10n.Settings.opus, L10n.Unit.kbps(opusBitrate / 1000))
            : codecAndRate(format)
        return L10n.Common.joined([
            codec,
            channels(format),
            transport == .tcpUDP ? L10n.Activity.udp : L10n.Activity.tcp,
        ])
    }

    private static func codecName(_ codec: AudioCodec) -> String {
        codec == .opus ? L10n.Settings.opus : L10n.Settings.pcmShort
    }
}
