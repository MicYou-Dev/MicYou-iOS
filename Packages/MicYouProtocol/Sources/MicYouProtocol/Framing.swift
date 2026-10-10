// SPDX-License-Identifier: GPL-3.0-or-later
// Frame layout: [magic u32 BE][payload length u32 BE][MessageWrapper]

import Foundation

public enum FrameError: Error, Equatable {
    case badMagic(UInt32)
    case badLength(Int)
}

public enum MicYouFrame {
    public static func tcp(_ message: MessageWrapper) -> Data {
        frame(magic: MicYouWire.tcpMagic, payload: message.serialized())
    }

    public static func udp(_ message: MessageWrapper) -> Data {
        frame(magic: MicYouWire.udpMagic, payload: message.serialized())
    }

    static func frame(magic: UInt32, payload: Data) -> Data {
        var out = Data(capacity: MicYouWire.headerSize + payload.count)
        appendBE(magic, to: &out)
        appendBE(UInt32(payload.count), to: &out)
        out.append(payload)
        return out
    }

    private static func appendBE(_ value: UInt32, to data: inout Data) {
        withUnsafeBytes(of: value.bigEndian) { data.append(contentsOf: $0) }
    }
}

/// Reassembles TCP frames from arbitrarily split reads
public struct FrameDecoder: Sendable {
    private var buffer: [UInt8] = []
    private var start = 0
    private let magic: UInt32

    public init(magic: UInt32 = MicYouWire.tcpMagic) {
        self.magic = magic
    }

    public var bufferedByteCount: Int { buffer.count - start }

    public mutating func append(_ data: Data) {
        if start > 0 && start >= buffer.count / 2 {
            buffer.removeFirst(start)
            start = 0
        }
        buffer.append(contentsOf: data)
    }

    /// Returns the next complete payload, nil when more bytes are needed
    public mutating func nextPayload() throws -> Data? {
        guard bufferedByteCount >= MicYouWire.headerSize else { return nil }
        let foundMagic = readBE(at: start)
        guard foundMagic == magic else { throw FrameError.badMagic(foundMagic) }
        let length = Int(readBE(at: start + 4))
        guard length <= MicYouWire.maxControlPayload else { throw FrameError.badLength(length) }
        guard bufferedByteCount >= MicYouWire.headerSize + length else { return nil }
        let bodyStart = start + MicYouWire.headerSize
        let payload = Data(buffer[bodyStart..<bodyStart + length])
        start = bodyStart + length
        return payload
    }

    public mutating func nextMessage() throws -> MessageWrapper? {
        guard let payload = try nextPayload() else { return nil }
        return try MessageWrapper(serialized: payload)
    }

    private func readBE(at offset: Int) -> UInt32 {
        UInt32(buffer[offset]) << 24 | UInt32(buffer[offset + 1]) << 16
            | UInt32(buffer[offset + 2]) << 8 | UInt32(buffer[offset + 3])
    }
}
