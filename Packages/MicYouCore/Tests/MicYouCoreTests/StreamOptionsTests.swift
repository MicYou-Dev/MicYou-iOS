// SPDX-License-Identifier: GPL-3.0-or-later

import MicYouProtocol
import Testing
@testable import MicYouCore

@Suite struct Options {
    private func options(codec: CodecChoice = .opus, transport: TransportMode = .tcpUDP, bitrate: Int = 64000, fec: Bool = true) -> StreamOptions {
        StreamOptions(transport: transport, codec: codec, sampleRate: 48000, channels: 1, opusBitrate: bitrate, fecEnabled: fec)
    }

    @Test func opusMapsUnsupportedRatesTo48k() {
        #expect(CodecChoice.opus.streamRate(forCaptureRate: 44100) == 48000)
        #expect(CodecChoice.opus.streamRate(forCaptureRate: 16000) == 16000)
        #expect(CodecChoice.pcm.streamRate(forCaptureRate: 44100) == 44100)
    }

    @Test func presetsMatchTheirOwnSettings() {
        for preset in StreamPreset.allCases {
            let match = StreamPreset.matching(
                transport: preset.transport, codec: preset.codec, sampleRate: preset.sampleRate, opusBitrate: preset.opusBitrate
            )
            #expect(match == preset)
        }
    }

    @Test func pcmPresetIgnoresBitrate() {
        #expect(StreamPreset.matching(transport: .tcpUDP, codec: .pcm, sampleRate: 48000, opusBitrate: 32000) == .lossless)
        #expect(StreamPreset.matching(transport: .tcpUDP, codec: .opus, sampleRate: 48000, opusBitrate: 32000) == nil)
        #expect(StreamPreset.matching(transport: .tcpUDP, codec: .opus, sampleRate: 16000, opusBitrate: 64000) == nil)
    }

    @Test func requestedFormatCarriesCodecAndChannels() {
        var value = options(codec: .pcm)
        value.channels = 2
        #expect(value.requestedFormat == AudioStreamFormat(sampleRate: 48000, channelCount: 2, codec: .pcm))
    }

    @Test func summaries() {
        #expect(options().summary == "Opus 64 kbps, 48000 Hz mono, UDP with FEC")
        #expect(options(codec: .pcm, transport: .tcp).summary == "PCM, 48000 Hz mono, TCP only")
        var stereo = options(fec: false)
        stereo.channels = 2
        #expect(stereo.summary == "Opus 64 kbps, 48000 Hz stereo, UDP")
    }

    @Test func estimatedBitrates() {
        // One parity packet per group of 12
        #expect(options().estimatedBitrate == 64000 * 13 / 12)
        var pcm = options(codec: .pcm, transport: .tcp)
        pcm.channels = 2
        #expect(pcm.estimatedBitrate == 48000 * 16 * 2)
    }

    @Test func fecOnlyCountsOverUDP() {
        #expect(options(transport: .tcpUDP, fec: true).usesFEC)
        #expect(!options(transport: .tcp, fec: true).usesFEC)
    }

    @Test func usbAlwaysSendsAudioOverTCP() {
        let usb = options(transport: .tcpUDP, fec: true).overUSB
        #expect(usb.transport == .tcp)
        #expect(!usb.usesFEC)
        #expect(usb.summary == "Opus 64 kbps, 48000 Hz mono, TCP only")
        // Switching transport in settings changes nothing a USB stream would use
        #expect(!options(transport: .tcpUDP).overUSB.differs(from: options(transport: .tcp).overUSB))
    }

    @Test func changesThatCannotTakeEffectAreIgnored() {
        #expect(!options(codec: .pcm, bitrate: 64000).differs(from: options(codec: .pcm, bitrate: 128000)))
        #expect(!options(transport: .tcp, fec: true).differs(from: options(transport: .tcp, fec: false)))
        #expect(options(bitrate: 64000).differs(from: options(bitrate: 128000)))
        #expect(options(transport: .tcpUDP).differs(from: options(transport: .tcp)))
        #expect(!options().differs(from: options()))
    }
}

@Suite struct Reconnect {
    @Test func delaysDoubleThenCap() {
        let policy = ReconnectPolicy.standard
        let delays = (1...policy.maxAttempts).map { policy.delay(beforeAttempt: $0) }
        #expect(delays == [1, 2, 4, 8, 15, 15])
    }

    @Test func retriesOnlyWorkingStreamsWithTransientErrors() {
        let policy = ReconnectPolicy.standard
        #expect(policy.shouldRetry(attempt: 1, enabled: true, hasStreamed: true, errorIsTransient: true))
        #expect(policy.shouldRetry(attempt: 6, enabled: true, hasStreamed: true, errorIsTransient: true))
        #expect(!policy.shouldRetry(attempt: 7, enabled: true, hasStreamed: true, errorIsTransient: true))
        #expect(!policy.shouldRetry(attempt: 1, enabled: false, hasStreamed: true, errorIsTransient: true))
        #expect(!policy.shouldRetry(attempt: 1, enabled: true, hasStreamed: false, errorIsTransient: true))
        #expect(!policy.shouldRetry(attempt: 1, enabled: true, hasStreamed: true, errorIsTransient: false))
    }
}

@Suite struct ServiceNames {
    @Test func stripsTheDesktopPrefix() {
        #expect(ServiceName.displayName("MicYou (DESKTOP-1234)") == "DESKTOP-1234")
        #expect(ServiceName.displayName("MicYou (my (pc))") == "my (pc)")
        #expect(ServiceName.displayName("Other") == "Other")
    }
}

@Suite struct Inputs {
    @Test(arguments: [
        InputPreference.automatic, .builtIn(nil), .builtIn(.bottom), .builtIn(.front), .builtIn(.back),
        .external(uid: "USB:1234"), .external(uid: "a.b.c"),
    ])
    func roundTrips(_ preference: InputPreference) {
        #expect(InputPreference(storageValue: preference.storageValue) == preference)
    }

    @Test func anonymizedHidesTheUID() {
        #expect(InputPreference.external(uid: "USB:1234").anonymized == "external")
        #expect(InputPreference.builtIn(.front).anonymized == "builtIn.front")
    }

    @Test(arguments: ["", "nonsense", "builtIn.left", "external."])
    func unknownValuesAreAutomatic(_ value: String) {
        #expect(InputPreference(storageValue: value) == .automatic)
    }
}
