// SPDX-License-Identifier: GPL-3.0-or-later
// Minimal proto3 wire encoder and decoder, enough for network.proto

import Foundation

public enum ProtoError: Error, Equatable {
    case truncated
    case malformedVarint
    case unsupportedWireType(UInt8)
    case invalidLength
}

public enum WireType: UInt8, Sendable {
    case varint = 0
    case fixed64 = 1
    case lengthDelimited = 2
    case fixed32 = 5
}

public struct ProtoWriter: Sendable {
    public private(set) var bytes: [UInt8] = []

    public init() {}

    public var data: Data { Data(bytes) }

    public mutating func writeVarint(_ value: UInt64) {
        var v = value
        while v >= 0x80 {
            bytes.append(UInt8(truncatingIfNeeded: v) | 0x80)
            v >>= 7
        }
        bytes.append(UInt8(v))
    }

    public mutating func writeTag(_ field: Int, _ type: WireType) {
        writeVarint(UInt64(field) << 3 | UInt64(type.rawValue))
    }

    /// proto3 scalars are skipped when they hold the default value
    public mutating func writeInt32(_ field: Int, _ value: Int32) {
        guard value != 0 else { return }
        writeTag(field, .varint)
        // Negative int32 is sign extended to ten bytes, as protobuf does
        writeVarint(UInt64(bitPattern: Int64(value)))
    }

    public mutating func writeInt64(_ field: Int, _ value: Int64) {
        guard value != 0 else { return }
        writeTag(field, .varint)
        writeVarint(UInt64(bitPattern: value))
    }

    public mutating func writeBool(_ field: Int, _ value: Bool, explicitPresence: Bool = false) {
        guard value || explicitPresence else { return }
        writeTag(field, .varint)
        writeVarint(value ? 1 : 0)
    }

    public mutating func writeBytes(_ field: Int, _ value: Data) {
        guard !value.isEmpty else { return }
        writeLengthDelimited(field, value)
    }

    /// Embedded messages are written even when empty, presence matters
    public mutating func writeMessage(_ field: Int, _ value: Data) {
        writeLengthDelimited(field, value)
    }

    public mutating func writePackedUInt32(_ field: Int, _ values: [UInt32]) {
        guard !values.isEmpty else { return }
        var inner = ProtoWriter()
        for v in values { inner.writeVarint(UInt64(v)) }
        writeTag(field, .lengthDelimited)
        writeVarint(UInt64(inner.bytes.count))
        bytes.append(contentsOf: inner.bytes)
    }

    private mutating func writeLengthDelimited(_ field: Int, _ value: Data) {
        writeTag(field, .lengthDelimited)
        writeVarint(UInt64(value.count))
        bytes.append(contentsOf: value)
    }
}

public struct ProtoReader {
    private let bytes: [UInt8]
    private var index = 0

    public init(_ data: Data) {
        bytes = [UInt8](data)
    }

    public var isAtEnd: Bool { index >= bytes.count }

    public mutating func nextTag() throws -> (field: Int, type: WireType)? {
        guard !isAtEnd else { return nil }
        let key = try readVarint()
        let raw = UInt8(key & 0x7)
        guard let type = WireType(rawValue: raw) else { throw ProtoError.unsupportedWireType(raw) }
        return (Int(key >> 3), type)
    }

    public mutating func readVarint() throws -> UInt64 {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        while true {
            guard index < bytes.count else { throw ProtoError.truncated }
            let byte = bytes[index]
            index += 1
            if shift == 63 && byte > 1 { throw ProtoError.malformedVarint }
            result |= UInt64(byte & 0x7F) << shift
            if byte & 0x80 == 0 { return result }
            shift += 7
            if shift > 63 { throw ProtoError.malformedVarint }
        }
    }

    public mutating func readInt32() throws -> Int32 {
        Int32(truncatingIfNeeded: try readVarint())
    }

    public mutating func readInt64() throws -> Int64 {
        Int64(bitPattern: try readVarint())
    }

    public mutating func readBool() throws -> Bool {
        try readVarint() != 0
    }

    public mutating func readLengthDelimited() throws -> Data {
        let length = try readVarint()
        guard length <= UInt64(bytes.count - index) else { throw ProtoError.invalidLength }
        let end = index + Int(length)
        defer { index = end }
        return Data(bytes[index..<end])
    }

    /// Accepts both packed and unpacked encodings of a repeated uint32
    public mutating func readUInt32s(_ type: WireType, into values: inout [UInt32]) throws {
        if type == .lengthDelimited {
            var inner = ProtoReader(try readLengthDelimited())
            while !inner.isAtEnd {
                values.append(UInt32(truncatingIfNeeded: try inner.readVarint()))
            }
        } else {
            values.append(UInt32(truncatingIfNeeded: try readVarint()))
        }
    }

    public mutating func skip(_ type: WireType) throws {
        switch type {
        case .varint: _ = try readVarint()
        case .lengthDelimited: _ = try readLengthDelimited()
        case .fixed64: try advance(8)
        case .fixed32: try advance(4)
        }
    }

    private mutating func advance(_ count: Int) throws {
        guard bytes.count - index >= count else { throw ProtoError.truncated }
        index += count
    }
}
