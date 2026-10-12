// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import MicYouProtocol

// Golden bytes come from, run in Packages/MicYouProtocol:
// protoc --encode=micyou.MessageWrapper -I Proto Proto/network.proto
private func hex(_ s: String) -> Data {
    var data = Data()
    var i = s.startIndex
    while i < s.endIndex {
        let j = s.index(i, offsetBy: 2)
        data.append(UInt8(s[i..<j], radix: 16)!)
        i = j
    }
    return data
}

@Suite struct GoldenEncoding {
    @Test func connect() {
        #expect(MessageWrapper.connect(sessionId: 1_234_567_890_123).serialized() == hex("120c08cb89ec8ff7231203696f73"))
        // Legacy encoding without a platform, which older desktops and clients still use
        #expect(MessageWrapper.connect(sessionId: 1_234_567_890_123, platform: "").serialized() == hex("120708cb89ec8ff723"))
    }

    @Test func muteKeepsExplicitFalse() {
        #expect(MessageWrapper.mute(true).serialized() == hex("1a020801"))
        #expect(MessageWrapper.mute(false).serialized() == hex("1a020800"))
    }

    @Test func pingPong() {
        #expect(MessageWrapper.ping(1_760_000_000_000).serialized() == hex("2a07088080b3c19c33"))
        #expect(MessageWrapper.pong(0).serialized() == hex("3200"))
    }

    @Test func audioPacket() {
        var packet = AudioPacketMessageOrdered()
        packet.sequenceNumber = 5
        packet.audioPacket = AudioPacketMessage(
            buffer: Data([1, 2, 3, 4]), sampleRate: 48000, channelCount: 2, audioFormat: .pcm16, codec: .opus)
        packet.timestamp = 1_760_000_000_123
        packet.sessionId = -42
        let golden = hex("0a26080512100a04010203041080f70218022002280118fb80b3c19c3330d6ffffffffffffffff01")
        #expect(MessageWrapper.audio(packet).serialized() == golden)
    }

    @Test func fecPacket() {
        var packet = AudioPacketMessageOrdered()
        packet.sequenceNumber = 12
        packet.audioPacket = AudioPacketMessage(
            buffer: Data([0xFF]), sampleRate: 16000, channelCount: 1, audioFormat: .pcm16, codec: .pcm)
        packet.timestamp = 1
        packet.fecBuffer = Data([1])
        packet.sessionId = 7
        packet.fecPacketLengths = [1, 2, 1320]
        #expect(MessageWrapper.audio(packet).serialized() == hex("0a1b080c120a0a01ff10807d18012002180122010130073a040102a80a"))
    }

    @Test func negativeInt32IsSignExtended() {
        var packet = AudioPacketMessageOrdered()
        packet.sequenceNumber = -1
        #expect(MessageWrapper.audio(packet).serialized() == hex("0a0b08ffffffffffffffffff01"))
    }
}

@Suite struct Decoding {
    @Test func roundTrip() throws {
        var packet = AudioPacketMessageOrdered()
        packet.sequenceNumber = Int32.max
        packet.audioPacket = AudioPacketMessage(
            buffer: Data(repeating: 9, count: 300), sampleRate: 48000, channelCount: 1, audioFormat: .pcm16, codec: .pcm)
        packet.timestamp = Int64.max
        packet.fecBuffer = Data([1])
        packet.fecSequenceNumber = 99
        packet.sessionId = Int64.min
        packet.fecPacketLengths = [UInt32](repeating: 1320, count: 12)
        let wrapper = MessageWrapper.audio(packet)
        #expect(try MessageWrapper(serialized: wrapper.serialized()) == wrapper)
    }

    @Test func statsFromDesktop() throws {
        let decoded = try MessageWrapper(serialized: hex("420e080c150000c03f1d0000803e202a"))
        let stats = try #require(decoded.stats)
        #expect(stats.rttMs == 12)
        #expect(stats.jitterMs == 1.5)
        #expect(stats.packetLoss == 0.25)
        #expect(stats.latencyMs == 42)
        #expect(decoded.serialized() == hex("420e080c150000c03f1d0000803e202a"))
    }

    @Test func absentMuteValueIsNil() throws {
        let decoded = try MessageWrapper(serialized: hex("1a00"))
        #expect(decoded.mute != nil)
        #expect(decoded.mute?.isMuted == nil)
    }

    @Test func skipsPluginMessage() throws {
        // ping { timestamp: 3 } pluginMessage { topic: "x" payload: "\001" }
        let decoded = try MessageWrapper(serialized: hex("2a0208033a061a0178220101"))
        #expect(decoded.ping?.timestamp == 3)
    }

    @Test func unpackedRepeatedIsAccepted() throws {
        let decoded = try AudioPacketMessageOrdered(serialized: hex("38053806"))
        #expect(decoded.fecPacketLengths == [5, 6])
    }

    @Test func truncatedInputThrows() {
        #expect(throws: ProtoError.self) { try MessageWrapper(serialized: hex("2a07088080")) }
    }
}
