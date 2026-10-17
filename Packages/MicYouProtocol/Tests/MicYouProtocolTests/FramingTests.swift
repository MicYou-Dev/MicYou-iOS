// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import MicYouProtocol

@Suite struct Framing {
    @Test func tcpHeaderIsBigEndian() {
        let frame = MicYouFrame.tcp(.mute(true))
        #expect(Array(frame.prefix(8)) == [0x4D, 0x69, 0x63, 0x59, 0, 0, 0, 4])
        #expect(Array(frame.dropFirst(8)) == [0x1A, 0x02, 0x08, 0x01])
    }

    @Test func decoderHandlesSplitAndCoalescedReads() throws {
        let stream = MicYouFrame.tcp(.ping(1)) + MicYouFrame.tcp(.mute(false)) + MicYouFrame.tcp(.ping(2))
        var decoder = FrameDecoder()
        var messages: [MessageWrapper] = []
        for byte in stream {
            decoder.append(Data([byte]))
            while let m = try decoder.nextMessage() { messages.append(m) }
        }
        #expect(messages == [.ping(1), .mute(false), .ping(2)])
        #expect(decoder.bufferedByteCount == 0)

        decoder.append(stream)
        var count = 0
        while try decoder.nextMessage() != nil { count += 1 }
        #expect(count == 3)
    }

    @Test func decoderRejectsBadMagicAndLength() {
        var bad = FrameDecoder()
        bad.append(Data([0, 0, 0, 0, 0, 0, 0, 0]))
        #expect(throws: FrameError.badMagic(0)) { try bad.nextPayload() }

        var huge = FrameDecoder()
        huge.append(Data([0x4D, 0x69, 0x63, 0x59, 0x7F, 0xFF, 0xFF, 0xFF]))
        #expect(throws: FrameError.badLength(0x7FFF_FFFF)) { try huge.nextPayload() }
    }
}

@Suite struct Sequencing {
    let format = AudioStreamFormat(sampleRate: 48000, channelCount: 2, codec: .pcm)

    @Test func fecParityAfterTwelvePackets() {
        var sequencer = AudioSequencer(sessionId: 5, fecEnabled: true)
        var all: [AudioPacketMessageOrdered] = []
        for i in 0..<25 {
            all += sequencer.packets(for: Data(repeating: UInt8(i + 1), count: i % 3 + 1), format: format, timestamp: 0)
        }
        let parity = all.filter(\.isFEC)
        #expect(parity.count == 2)
        #expect(parity[0].sequenceNumber == 12)
        #expect(parity[0].fecSequenceNumber == 0)
        #expect(parity[1].fecSequenceNumber == 12)
        #expect(parity[0].fecPacketLengths.count == 12)
        #expect(parity[0].fecBuffer == Data([1]))
        #expect(all.filter { !$0.isFEC }.map(\.sequenceNumber) == Array(0..<25))

        // XOR of the group recovers any single member
        let group = all.filter { !$0.isFEC && $0.sequenceNumber < 12 }.map { $0.audioPacket!.buffer }
        var recovered = [UInt8](parity[0].audioPacket!.buffer)
        for (i, b) in group.enumerated() where i != 4 {
            for (j, x) in b.enumerated() { recovered[j] ^= x }
        }
        #expect(Data(recovered.prefix(Int(parity[0].fecPacketLengths[4]))) == group[4])
    }

    @Test func udpDatagramFitsMTU() {
        // Worst case: ten byte varints for session id and timestamp
        var sequencer = AudioSequencer(sessionId: Int64.min, fecEnabled: true)
        var largest = 0
        for _ in 0..<12 {
            for packet in sequencer.packets(for: Data(repeating: 0xAB, count: MicYouWire.udpPCMPayload), format: format, timestamp: Int64.max) {
                largest = max(largest, MicYouFrame.udp(.audio(packet)).count)
            }
        }
        #expect(largest <= MicYouWire.udpMaxDatagram)
    }

    @Test func chunkerAlignsToFrames() {
        var chunker = PCMChunker(frameBytes: 6)
        #expect(chunker.chunkSize == 1320)
        var chunks = chunker.append(Data(count: 1000))
        #expect(chunks.isEmpty)
        chunks = chunker.append(Data(count: 2000))
        #expect(chunks.map(\.count) == [1320, 1320])
        #expect(PCMChunker(frameBytes: 4).chunkSize == 1320)
        #expect(PCMChunker(frameBytes: 7).chunkSize == 1316)
    }

    @Test func chunkerKeepsByteOrderAcrossAppends() {
        var chunker = PCMChunker(frameBytes: 4, maxChunk: 4)
        #expect(chunker.append(Data([0, 1, 2])).isEmpty)
        #expect(chunker.append(Data([3, 4, 5, 6, 7, 8, 9])) == [Data([0, 1, 2, 3]), Data([4, 5, 6, 7])])
        chunker.reset()
        #expect(chunker.append(Data([10, 11, 12, 13])) == [Data([10, 11, 12, 13])])
    }
}
