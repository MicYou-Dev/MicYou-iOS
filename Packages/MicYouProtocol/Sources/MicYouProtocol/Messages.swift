// SPDX-License-Identifier: GPL-3.0-or-later
// Swift mirror of Proto/network.proto (package micyou)

import Foundation

public protocol ProtoMessage: Sendable, Equatable {
    init()
    func encode(into writer: inout ProtoWriter)
    /// Called for every field, unknown fields must be skipped
    mutating func decodeField(_ field: Int, _ type: WireType, _ reader: inout ProtoReader) throws
}

extension ProtoMessage {
    public func serialized() -> Data {
        var writer = ProtoWriter()
        encode(into: &writer)
        return writer.data
    }

    public init(serialized data: Data) throws {
        self.init()
        var reader = ProtoReader(data)
        while let (field, type) = try reader.nextTag() {
            try decodeField(field, type, &reader)
        }
    }
}

public struct ConnectMessage: ProtoMessage {
    public var sessionId: Int64 = 0

    public init() {}
    public init(sessionId: Int64) { self.sessionId = sessionId }

    public func encode(into w: inout ProtoWriter) {
        w.writeInt64(1, sessionId)
    }

    public mutating func decodeField(_ field: Int, _ type: WireType, _ r: inout ProtoReader) throws {
        if field == 1, type == .varint { sessionId = try r.readInt64() } else { try r.skip(type) }
    }
}

public struct MuteMessage: ProtoMessage {
    /// `optional bool`, nil means the field was absent which the desktop reads as false
    public var isMuted: Bool?

    public init() {}
    public init(isMuted: Bool) { self.isMuted = isMuted }

    public func encode(into w: inout ProtoWriter) {
        if let isMuted { w.writeBool(1, isMuted, explicitPresence: true) }
    }

    public mutating func decodeField(_ field: Int, _ type: WireType, _ r: inout ProtoReader) throws {
        if field == 1, type == .varint { isMuted = try r.readBool() } else { try r.skip(type) }
    }
}

/// PingMessage and PongMessage share this shape
public struct TimestampMessage: ProtoMessage {
    public var timestamp: Int64 = 0

    public init() {}
    public init(timestamp: Int64) { self.timestamp = timestamp }

    public func encode(into w: inout ProtoWriter) {
        w.writeInt64(1, timestamp)
    }

    public mutating func decodeField(_ field: Int, _ type: WireType, _ r: inout ProtoReader) throws {
        if field == 1, type == .varint { timestamp = try r.readInt64() } else { try r.skip(type) }
    }
}

public struct AudioPacketMessage: ProtoMessage {
    public var buffer = Data()
    public var sampleRate: Int32 = 0
    public var channelCount: Int32 = 0
    public var audioFormat: Int32 = 0
    public var codec: Int32 = 0

    public init() {}

    public init(buffer: Data, sampleRate: Int32, channelCount: Int32, audioFormat: WireAudioFormat, codec: AudioCodec) {
        self.buffer = buffer
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.audioFormat = audioFormat.rawValue
        self.codec = codec.rawValue
    }

    public func encode(into w: inout ProtoWriter) {
        w.writeBytes(1, buffer)
        w.writeInt32(2, sampleRate)
        w.writeInt32(3, channelCount)
        w.writeInt32(4, audioFormat)
        w.writeInt32(5, codec)
    }

    public mutating func decodeField(_ field: Int, _ type: WireType, _ r: inout ProtoReader) throws {
        switch (field, type) {
        case (1, .lengthDelimited): buffer = try r.readLengthDelimited()
        case (2, .varint): sampleRate = try r.readInt32()
        case (3, .varint): channelCount = try r.readInt32()
        case (4, .varint): audioFormat = try r.readInt32()
        case (5, .varint): codec = try r.readInt32()
        default: try r.skip(type)
        }
    }
}

public struct AudioPacketMessageOrdered: ProtoMessage {
    public var sequenceNumber: Int32 = 0
    public var audioPacket: AudioPacketMessage?
    /// Unix time in milliseconds
    public var timestamp: Int64 = 0
    /// Non-empty marker on FEC parity packets
    public var fecBuffer = Data()
    public var fecSequenceNumber: Int32 = 0
    public var sessionId: Int64 = 0
    public var fecPacketLengths: [UInt32] = []

    public init() {}

    public var isFEC: Bool { !fecBuffer.isEmpty }

    public func encode(into w: inout ProtoWriter) {
        w.writeInt32(1, sequenceNumber)
        if let audioPacket { w.writeMessage(2, audioPacket.serialized()) }
        w.writeInt64(3, timestamp)
        w.writeBytes(4, fecBuffer)
        w.writeInt32(5, fecSequenceNumber)
        w.writeInt64(6, sessionId)
        w.writePackedUInt32(7, fecPacketLengths)
    }

    public mutating func decodeField(_ field: Int, _ type: WireType, _ r: inout ProtoReader) throws {
        switch (field, type) {
        case (1, .varint): sequenceNumber = try r.readInt32()
        case (2, .lengthDelimited): audioPacket = try AudioPacketMessage(serialized: r.readLengthDelimited())
        case (3, .varint): timestamp = try r.readInt64()
        case (4, .lengthDelimited): fecBuffer = try r.readLengthDelimited()
        case (5, .varint): fecSequenceNumber = try r.readInt32()
        case (6, .varint): sessionId = try r.readInt64()
        case (7, .varint), (7, .lengthDelimited): try r.readUInt32s(type, into: &fecPacketLengths)
        default: try r.skip(type)
        }
    }
}

public struct MessageWrapper: ProtoMessage {
    public var audioPacket: AudioPacketMessageOrdered?
    public var connect: ConnectMessage?
    public var mute: MuteMessage?
    public var ping: TimestampMessage?
    public var pong: TimestampMessage?
    // Field 7 (pluginMessage) is not used by this client and is skipped on decode

    public init() {}

    public static func connect(sessionId: Int64) -> MessageWrapper {
        var m = MessageWrapper()
        m.connect = ConnectMessage(sessionId: sessionId)
        return m
    }

    public static func mute(_ isMuted: Bool) -> MessageWrapper {
        var m = MessageWrapper()
        m.mute = MuteMessage(isMuted: isMuted)
        return m
    }

    public static func ping(_ timestamp: Int64) -> MessageWrapper {
        var m = MessageWrapper()
        m.ping = TimestampMessage(timestamp: timestamp)
        return m
    }

    public static func pong(_ timestamp: Int64) -> MessageWrapper {
        var m = MessageWrapper()
        m.pong = TimestampMessage(timestamp: timestamp)
        return m
    }

    public static func audio(_ packet: AudioPacketMessageOrdered) -> MessageWrapper {
        var m = MessageWrapper()
        m.audioPacket = packet
        return m
    }

    public func encode(into w: inout ProtoWriter) {
        if let audioPacket { w.writeMessage(1, audioPacket.serialized()) }
        if let connect { w.writeMessage(2, connect.serialized()) }
        if let mute { w.writeMessage(3, mute.serialized()) }
        if let ping { w.writeMessage(5, ping.serialized()) }
        if let pong { w.writeMessage(6, pong.serialized()) }
    }

    public mutating func decodeField(_ field: Int, _ type: WireType, _ r: inout ProtoReader) throws {
        guard type == .lengthDelimited else { return try r.skip(type) }
        switch field {
        case 1: audioPacket = try AudioPacketMessageOrdered(serialized: r.readLengthDelimited())
        case 2: connect = try ConnectMessage(serialized: r.readLengthDelimited())
        case 3: mute = try MuteMessage(serialized: r.readLengthDelimited())
        case 5: ping = try TimestampMessage(serialized: r.readLengthDelimited())
        case 6: pong = try TimestampMessage(serialized: r.readLengthDelimited())
        default: try r.skip(type)
        }
    }
}
