// SPDX-License-Identifier: GPL-3.0-or-later

@preconcurrency import AVFoundation
import AudioToolbox
import Foundation

enum OpusEncoderError: Error {
    case unsupportedFormat
    case encodeFailed(OSStatus)
}

/// Encodes interleaved Int16 PCM into raw 20 ms Opus packets with the system Opus encoder
/// Not thread safe, owned by the stream queue
final class OpusEncoder {
    /// Opus only runs at these rates, the desktop decoder accepts the same set
    static let supportedRates: [Double] = [48000, 24000, 16000, 12000, 8000]

    let sampleRate: Double
    let channels: AVAudioChannelCount
    let framesPerPacket: AVAudioFrameCount

    private let converter: AVAudioConverter
    private let input: AVAudioPCMBuffer
    private let output: AVAudioCompressedBuffer
    private var pending = Data()

    /// Keeps a supported capture rate and sends anything else at 48 kHz, so 44.1 kHz maps to 48 kHz like on Android
    static func opusRate(for captureRate: Double) -> Double {
        supportedRates.contains(captureRate) ? captureRate : 48000
    }

    init(sampleRate: Double, channels: AVAudioChannelCount, bitrate: Int) throws {
        self.sampleRate = sampleRate
        self.channels = channels
        framesPerPacket = AVAudioFrameCount(sampleRate / 50)

        var description = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatOpus,
            mFormatFlags: 0,
            mBytesPerPacket: 0,
            mFramesPerPacket: UInt32(framesPerPacket),
            mBytesPerFrame: 0,
            mChannelsPerFrame: channels,
            mBitsPerChannel: 0,
            mReserved: 0
        )
        guard
            let pcmFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: sampleRate, channels: channels, interleaved: true),
            let opusFormat = AVAudioFormat(streamDescription: &description),
            let converter = AVAudioConverter(from: pcmFormat, to: opusFormat),
            let input = AVAudioPCMBuffer(pcmFormat: pcmFormat, frameCapacity: framesPerPacket)
        else { throw OpusEncoderError.unsupportedFormat }

        if let rates = converter.applicableEncodeBitRates?.map(\.intValue), !rates.isEmpty {
            converter.bitRate = rates.min { abs($0 - bitrate) < abs($1 - bitrate) } ?? bitrate
        } else {
            converter.bitRate = bitrate
        }
        let maxPacket = max(converter.maximumOutputPacketSize, 1500)
        self.converter = converter
        self.input = input
        output = AVAudioCompressedBuffer(format: opusFormat, packetCapacity: 1, maximumPacketSize: maxPacket)
    }

    var bytesPerFrame: Int { Int(channels) * 2 }

    /// Buffers PCM and returns one Opus packet per complete 20 ms frame
    func encode(_ pcm: Data) throws -> [Data] {
        pending.append(pcm)
        let frameBytes = Int(framesPerPacket) * bytesPerFrame
        var packets: [Data] = []
        while pending.count >= frameBytes {
            let chunk = pending.prefix(frameBytes)
            if let packet = try encodeFrame(chunk) {
                packets.append(packet)
            }
            pending.removeFirst(frameBytes)
        }
        return packets
    }

    func reset() {
        pending.removeAll(keepingCapacity: true)
        converter.reset()
    }

    private func encodeFrame(_ chunk: Data) throws -> Data? {
        guard let dst = input.int16ChannelData?[0] else { return nil }
        chunk.withUnsafeBytes { raw in
            _ = memcpy(dst, raw.baseAddress!, chunk.count)
        }
        input.frameLength = framesPerPacket

        var supplied = false
        var error: NSError?
        output.packetCount = 0
        output.byteLength = 0
        let status = converter.convert(to: output, error: &error) { [input] _, inputStatus in
            if supplied {
                inputStatus.pointee = .noDataNow
                return nil
            }
            supplied = true
            inputStatus.pointee = .haveData
            return input
        }
        if status == .error {
            throw OpusEncoderError.encodeFailed(OSStatus((error?.code) ?? -1))
        }
        guard output.packetCount > 0 else { return nil }
        var offset = 0
        var size = Int(output.byteLength)
        if let descriptions = output.packetDescriptions {
            offset = Int(descriptions[0].mStartOffset)
            size = Int(descriptions[0].mDataByteSize)
        }
        guard size > 0 else { return nil }
        return Data(bytes: output.data.advanced(by: offset), count: size)
    }
}
