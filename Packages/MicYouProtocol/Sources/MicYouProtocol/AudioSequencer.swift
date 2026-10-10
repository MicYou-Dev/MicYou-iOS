// SPDX-License-Identifier: GPL-3.0-or-later
// Turns encoded audio payloads into ordered packets, with optional XOR FEC
// Ported from the Android sender in MicYou-Dev/MicYou (AudioEngine.kt)

import Foundation

public struct AudioStreamFormat: Sendable, Equatable {
    public var sampleRate: Int32
    public var channelCount: Int32
    public var audioFormat: WireAudioFormat
    public var codec: AudioCodec

    public init(sampleRate: Int32, channelCount: Int32, audioFormat: WireAudioFormat = .pcm16, codec: AudioCodec) {
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.audioFormat = audioFormat
        self.codec = codec
    }

    /// Bytes per interleaved PCM frame, used to align raw PCM chunks
    public var pcmFrameBytes: Int { audioFormat.bytesPerSample * Int(channelCount) }
}

public struct AudioSequencer: Sendable {
    public let sessionId: Int64
    public var fecEnabled: Bool
    public private(set) var nextSequence: Int32 = 0

    private var fecGroup: [Data] = []
    private var fecGroupStart: Int32 = 0

    public init(sessionId: Int64, fecEnabled: Bool) {
        self.sessionId = sessionId
        self.fecEnabled = fecEnabled
    }

    /// One regular packet, followed by a parity packet whenever a FEC group fills up
    public mutating func packets(for payload: Data, format: AudioStreamFormat, timestamp: Int64) -> [AudioPacketMessageOrdered] {
        var regular = AudioPacketMessageOrdered()
        regular.sequenceNumber = nextSequence
        regular.audioPacket = AudioPacketMessage(
            buffer: payload,
            sampleRate: format.sampleRate,
            channelCount: format.channelCount,
            audioFormat: format.audioFormat,
            codec: format.codec
        )
        regular.timestamp = timestamp
        regular.sessionId = sessionId
        nextSequence &+= 1

        var out = [regular]
        guard fecEnabled else { return out }

        // The desktop only accepts group members of 1...udpPCMPayload bytes
        guard !payload.isEmpty, payload.count <= MicYouWire.udpPCMPayload else {
            resetFEC()
            return out
        }
        fecGroup.append(payload)
        if fecGroup.count >= MicYouWire.fecGroupSize {
            var parity = AudioPacketMessageOrdered()
            // Shares the next regular sequence number without consuming it
            parity.sequenceNumber = nextSequence
            parity.audioPacket = AudioPacketMessage(
                buffer: Self.xor(fecGroup),
                sampleRate: format.sampleRate,
                channelCount: format.channelCount,
                audioFormat: format.audioFormat,
                codec: format.codec
            )
            parity.timestamp = timestamp
            // Marker that tells group zero apart from an absent fecSequenceNumber
            parity.fecBuffer = Data([1])
            parity.fecSequenceNumber = fecGroupStart
            parity.sessionId = sessionId
            parity.fecPacketLengths = fecGroup.map { UInt32($0.count) }
            out.append(parity)
            fecGroup.removeAll(keepingCapacity: true)
            fecGroupStart = nextSequence
        }
        return out
    }

    /// Drops a partial FEC group, the next group starts at the next sequence number
    public mutating func resetFEC() {
        fecGroup.removeAll(keepingCapacity: true)
        fecGroupStart = nextSequence
    }

    static func xor(_ buffers: [Data]) -> Data {
        let maxLength = buffers.map(\.count).max() ?? 0
        var result = [UInt8](repeating: 0, count: maxLength)
        for buffer in buffers {
            buffer.withUnsafeBytes { raw in
                for i in 0..<raw.count { result[i] ^= raw[i] }
            }
        }
        return Data(result)
    }
}

/// Splits a PCM byte stream into frame aligned chunks that fit one UDP datagram
public struct PCMChunker: Sendable {
    public let chunkSize: Int
    private var pending = Data()

    public init(frameBytes: Int, maxChunk: Int = MicYouWire.udpPCMPayload) {
        precondition(frameBytes > 0)
        chunkSize = max(frameBytes, maxChunk / frameBytes * frameBytes)
    }

    public mutating func append(_ data: Data) -> [Data] {
        pending.append(data)
        var chunks: [Data] = []
        while pending.count >= chunkSize {
            chunks.append(Data(pending.prefix(chunkSize)))
            pending.removeFirst(chunkSize)
        }
        return chunks
    }

    public mutating func reset() {
        pending.removeAll(keepingCapacity: true)
    }
}
