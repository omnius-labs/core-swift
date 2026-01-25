import Foundation
import NIO

// https://cborbook.com/part_1/practical_introduction_to_cbor.html

public enum RocketPackEncoderError: Error, Sendable {
    case lengthOverflow(length: Int)
}

public protocol RocketPackEncoder {
    mutating func writeBool(_ value: Bool) throws
    mutating func writeU8(_ value: UInt8) throws
    mutating func writeU16(_ value: UInt16) throws
    mutating func writeU32(_ value: UInt32) throws
    mutating func writeU64(_ value: UInt64) throws
    mutating func writeI8(_ value: Int8) throws
    mutating func writeI16(_ value: Int16) throws
    mutating func writeI32(_ value: Int32) throws
    mutating func writeI64(_ value: Int64) throws
    mutating func writeF32(_ value: Float) throws
    mutating func writeF64(_ value: Double) throws
    mutating func writeBytes(_ value: [UInt8]) throws
    mutating func writeString(_ value: String) throws
    mutating func writeArray(_ length: Int) throws
    mutating func writeMap(_ length: Int) throws
    mutating func writeNull() throws
    mutating func writeStruct<T: RocketPackStruct>(_ value: T) throws
}

public struct RocketPackBytesEncoder: RocketPackEncoder, Sendable {

    public init(allocator: ByteBufferAllocator = .init()) {
        self.buffer = allocator.buffer(capacity: 32)
    }

    public var buffer: ByteBuffer

    public mutating func writeBool(_ value: Bool) throws {
        buffer.writeInteger(compose(major: 7, info: value ? 21 : 20), as: UInt8.self)
    }

    public mutating func writeU8(_ value: UInt8) throws {
        if value <= 23 {
            buffer.writeInteger(compose(major: 0, info: value), as: UInt8.self)
        } else {
            buffer.writeInteger(compose(major: 0, info: 24), as: UInt8.self)
            buffer.writeInteger(value, as: UInt8.self)
        }
    }

    public mutating func writeU16(_ value: UInt16) throws {
        if value <= 23 {
            buffer.writeInteger(compose(major: 0, info: UInt8(value)), as: UInt8.self)
        } else if value <= UInt16(UInt8.max) {
            buffer.writeInteger(compose(major: 0, info: 24), as: UInt8.self)
            buffer.writeInteger(UInt8(truncatingIfNeeded: value), as: UInt8.self)
        } else {
            buffer.writeInteger(compose(major: 0, info: 25), as: UInt8.self)
            appendInteger(value)
        }
    }

    public mutating func writeU32(_ value: UInt32) throws {
        if value <= 23 {
            buffer.writeInteger(compose(major: 0, info: UInt8(value)), as: UInt8.self)
        } else if value <= UInt32(UInt8.max) {
            buffer.writeInteger(compose(major: 0, info: 24), as: UInt8.self)
            buffer.writeInteger(UInt8(truncatingIfNeeded: value), as: UInt8.self)
        } else if value <= UInt32(UInt16.max) {
            buffer.writeInteger(compose(major: 0, info: 25), as: UInt8.self)
            appendInteger(UInt16(truncatingIfNeeded: value))
        } else {
            buffer.writeInteger(compose(major: 0, info: 26), as: UInt8.self)
            appendInteger(value)
        }
    }

    public mutating func writeU64(_ value: UInt64) throws {
        if value <= 23 {
            buffer.writeInteger(compose(major: 0, info: UInt8(value)), as: UInt8.self)
        } else if value <= UInt64(UInt8.max) {
            buffer.writeInteger(compose(major: 0, info: 24), as: UInt8.self)
            buffer.writeInteger(UInt8(truncatingIfNeeded: value), as: UInt8.self)
        } else if value <= UInt64(UInt16.max) {
            buffer.writeInteger(compose(major: 0, info: 25), as: UInt8.self)
            appendInteger(UInt16(truncatingIfNeeded: value))
        } else if value <= UInt64(UInt32.max) {
            buffer.writeInteger(compose(major: 0, info: 26), as: UInt8.self)
            appendInteger(UInt32(truncatingIfNeeded: value))
        } else {
            buffer.writeInteger(compose(major: 0, info: 27), as: UInt8.self)
            appendInteger(value)
        }
    }

    public mutating func writeI8(_ value: Int8) throws {
        if value >= 0 {
            try writeU8(UInt8(value))
            return
        }

        let magnitude = UInt8(bitPattern: ~value)
        if magnitude <= 23 {
            buffer.writeInteger(compose(major: 1, info: magnitude), as: UInt8.self)
        } else {
            buffer.writeInteger(compose(major: 1, info: 24), as: UInt8.self)
            buffer.writeInteger(magnitude, as: UInt8.self)
        }
    }

    public mutating func writeI16(_ value: Int16) throws {
        if value >= 0 {
            try writeU16(UInt16(value))
            return
        }

        let magnitude = UInt16(bitPattern: ~value)
        if magnitude <= 23 {
            buffer.writeInteger(compose(major: 1, info: UInt8(truncatingIfNeeded: magnitude)), as: UInt8.self)
        } else if magnitude <= UInt16(UInt8.max) {
            buffer.writeInteger(compose(major: 1, info: 24), as: UInt8.self)
            buffer.writeInteger(UInt8(truncatingIfNeeded: magnitude), as: UInt8.self)
        } else {
            buffer.writeInteger(compose(major: 1, info: 25), as: UInt8.self)
            appendInteger(magnitude)
        }
    }

    public mutating func writeI32(_ value: Int32) throws {
        if value >= 0 {
            try writeU32(UInt32(value))
            return
        }

        let magnitude = UInt32(bitPattern: ~value)
        if magnitude <= 23 {
            buffer.writeInteger(compose(major: 1, info: UInt8(truncatingIfNeeded: magnitude)), as: UInt8.self)
        } else if magnitude <= UInt32(UInt8.max) {
            buffer.writeInteger(compose(major: 1, info: 24), as: UInt8.self)
            buffer.writeInteger(UInt8(truncatingIfNeeded: magnitude), as: UInt8.self)
        } else if magnitude <= UInt32(UInt16.max) {
            buffer.writeInteger(compose(major: 1, info: 25), as: UInt8.self)
            appendInteger(UInt16(truncatingIfNeeded: magnitude))
        } else {
            buffer.writeInteger(compose(major: 1, info: 26), as: UInt8.self)
            appendInteger(magnitude)
        }
    }

    public mutating func writeI64(_ value: Int64) throws {
        if value >= 0 {
            try writeU64(UInt64(value))
            return
        }

        let magnitude = UInt64(bitPattern: ~value)
        if magnitude <= 23 {
            buffer.writeInteger(compose(major: 1, info: UInt8(truncatingIfNeeded: magnitude)), as: UInt8.self)
        } else if magnitude <= UInt64(UInt8.max) {
            buffer.writeInteger(compose(major: 1, info: 24), as: UInt8.self)
            buffer.writeInteger(UInt8(truncatingIfNeeded: magnitude), as: UInt8.self)
        } else if magnitude <= UInt64(UInt16.max) {
            buffer.writeInteger(compose(major: 1, info: 25), as: UInt8.self)
            appendInteger(UInt16(truncatingIfNeeded: magnitude))
        } else if magnitude <= UInt64(UInt32.max) {
            buffer.writeInteger(compose(major: 1, info: 26), as: UInt8.self)
            appendInteger(UInt32(truncatingIfNeeded: magnitude))
        } else {
            buffer.writeInteger(compose(major: 1, info: 27), as: UInt8.self)
            appendInteger(magnitude)
        }
    }

    public mutating func writeF32(_ value: Float) throws {
        buffer.writeInteger(compose(major: 7, info: 26), as: UInt8.self)
        appendInteger(value.bitPattern)
    }

    public mutating func writeF64(_ value: Double) throws {
        buffer.writeInteger(compose(major: 7, info: 27), as: UInt8.self)
        appendInteger(value.bitPattern)
    }

    public mutating func writeBytes(_ value: [UInt8]) throws {
        try writeRawLen(major: 2, length: checkedLength(value.count))
        buffer.writeBytes(value)
    }

    public mutating func writeString(_ value: String) throws {
        let utf8 = Array(value.utf8)
        try writeRawLen(major: 3, length: checkedLength(utf8.count))
        buffer.writeBytes(utf8)
    }

    public mutating func writeArray(_ length: Int) throws {
        try writeRawLen(major: 4, length: checkedLength(length))
    }

    public mutating func writeMap(_ length: Int) throws {
        try writeRawLen(major: 5, length: checkedLength(length))
    }

    public mutating func writeNull() throws {
        buffer.writeInteger(compose(major: 7, info: 22), as: UInt8.self)
    }

    public mutating func writeStruct<T>(_ value: T) throws where T: RocketPackStruct {
        try T.pack(encoder: &self, value: value)
    }

    mutating func writeRawLen(major: UInt8, length: UInt64) throws {
        if length <= 23 {
            buffer.writeInteger(compose(major: major, info: UInt8(length)), as: UInt8.self)
        } else if length <= UInt64(UInt8.max) {
            buffer.writeInteger(compose(major: major, info: 24), as: UInt8.self)
            buffer.writeInteger(UInt8(truncatingIfNeeded: length), as: UInt8.self)
        } else if length <= UInt64(UInt16.max) {
            buffer.writeInteger(compose(major: major, info: 25), as: UInt8.self)
            appendInteger(UInt16(truncatingIfNeeded: length))
        } else if length <= UInt64(UInt32.max) {
            buffer.writeInteger(compose(major: major, info: 26), as: UInt8.self)
            appendInteger(UInt32(truncatingIfNeeded: length))
        } else {
            buffer.writeInteger(compose(major: major, info: 27), as: UInt8.self)
            appendInteger(length)
        }
    }

    private func checkedLength(_ length: Int) throws -> UInt64 {
        guard length >= 0 else {
            throw RocketPackEncoderError.lengthOverflow(length: length)
        }
        return UInt64(length)
    }

    private mutating func appendInteger<T: FixedWidthInteger>(_ value: T) {
        buffer.writeInteger(value, endianness: .big)
    }

    @inline(__always)
    private func compose(major: UInt8, info: UInt8) -> UInt8 {
        (major << 5) | (info & 0b0001_1111)
    }
}
