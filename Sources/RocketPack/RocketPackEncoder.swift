import Foundation

// https://cborbook.com/part_1/practical_introduction_to_cbor.html

public enum RocketPackEncoderError: Error {
    case lengthOverflow(length: Int)
}

public protocol RocketPackEncoder: AnyObject {
    func writeBool(_ value: Bool) throws
    func writeU8(_ value: UInt8) throws
    func writeU16(_ value: UInt16) throws
    func writeU32(_ value: UInt32) throws
    func writeU64(_ value: UInt64) throws
    func writeI8(_ value: Int8) throws
    func writeI16(_ value: Int16) throws
    func writeI32(_ value: Int32) throws
    func writeI64(_ value: Int64) throws
    func writeF32(_ value: Float) throws
    func writeF64(_ value: Double) throws
    func writeBytes(_ value: [UInt8]) throws
    func writeString(_ value: String) throws
    func writeArray(_ length: Int) throws
    func writeMap(_ length: Int) throws
    func writeNull() throws
    func writeStruct<T: RocketPackStruct>(_ value: T) throws
}

public final class RocketPackBytesEncoder: RocketPackEncoder {
    private var storage: [UInt8]

    public init(capacity: Int = 0) {
        self.storage = []
        if capacity > 0 {
            self.storage.reserveCapacity(capacity)
        }
    }

    public var bytes: [UInt8] {
        storage
    }

    public func writeBool(_ value: Bool) throws {
        storage.append(compose(major: 7, info: value ? 21 : 20))
    }

    public func writeU8(_ value: UInt8) throws {
        if value <= 23 {
            storage.append(compose(major: 0, info: value))
        } else {
            storage.append(compose(major: 0, info: 24))
            storage.append(value)
        }
    }

    public func writeU16(_ value: UInt16) throws {
        if value <= 23 {
            storage.append(compose(major: 0, info: UInt8(value)))
        } else if value <= UInt16(UInt8.max) {
            storage.append(compose(major: 0, info: 24))
            storage.append(UInt8(truncatingIfNeeded: value))
        } else {
            storage.append(compose(major: 0, info: 25))
            appendInteger(value)
        }
    }

    public func writeU32(_ value: UInt32) throws {
        if value <= 23 {
            storage.append(compose(major: 0, info: UInt8(value)))
        } else if value <= UInt32(UInt8.max) {
            storage.append(compose(major: 0, info: 24))
            storage.append(UInt8(truncatingIfNeeded: value))
        } else if value <= UInt32(UInt16.max) {
            storage.append(compose(major: 0, info: 25))
            appendInteger(UInt16(truncatingIfNeeded: value))
        } else {
            storage.append(compose(major: 0, info: 26))
            appendInteger(value)
        }
    }

    public func writeU64(_ value: UInt64) throws {
        if value <= 23 {
            storage.append(compose(major: 0, info: UInt8(value)))
        } else if value <= UInt64(UInt8.max) {
            storage.append(compose(major: 0, info: 24))
            storage.append(UInt8(truncatingIfNeeded: value))
        } else if value <= UInt64(UInt16.max) {
            storage.append(compose(major: 0, info: 25))
            appendInteger(UInt16(truncatingIfNeeded: value))
        } else if value <= UInt64(UInt32.max) {
            storage.append(compose(major: 0, info: 26))
            appendInteger(UInt32(truncatingIfNeeded: value))
        } else {
            storage.append(compose(major: 0, info: 27))
            appendInteger(value)
        }
    }

    public func writeI8(_ value: Int8) throws {
        if value >= 0 {
            try writeU8(UInt8(value))
            return
        }

        let magnitude = UInt8(bitPattern: ~value)
        if magnitude <= 23 {
            storage.append(compose(major: 1, info: magnitude))
        } else {
            storage.append(compose(major: 1, info: 24))
            storage.append(magnitude)
        }
    }

    public func writeI16(_ value: Int16) throws {
        if value >= 0 {
            try writeU16(UInt16(value))
            return
        }

        let magnitude = UInt16(bitPattern: ~value)
        if magnitude <= 23 {
            storage.append(compose(major: 1, info: UInt8(truncatingIfNeeded: magnitude)))
        } else if magnitude <= UInt16(UInt8.max) {
            storage.append(compose(major: 1, info: 24))
            storage.append(UInt8(truncatingIfNeeded: magnitude))
        } else {
            storage.append(compose(major: 1, info: 25))
            appendInteger(magnitude)
        }
    }

    public func writeI32(_ value: Int32) throws {
        if value >= 0 {
            try writeU32(UInt32(value))
            return
        }

        let magnitude = UInt32(bitPattern: ~value)
        if magnitude <= 23 {
            storage.append(compose(major: 1, info: UInt8(truncatingIfNeeded: magnitude)))
        } else if magnitude <= UInt32(UInt8.max) {
            storage.append(compose(major: 1, info: 24))
            storage.append(UInt8(truncatingIfNeeded: magnitude))
        } else if magnitude <= UInt32(UInt16.max) {
            storage.append(compose(major: 1, info: 25))
            appendInteger(UInt16(truncatingIfNeeded: magnitude))
        } else {
            storage.append(compose(major: 1, info: 26))
            appendInteger(magnitude)
        }
    }

    public func writeI64(_ value: Int64) throws {
        if value >= 0 {
            try writeU64(UInt64(value))
            return
        }

        let magnitude = UInt64(bitPattern: ~value)
        if magnitude <= 23 {
            storage.append(compose(major: 1, info: UInt8(truncatingIfNeeded: magnitude)))
        } else if magnitude <= UInt64(UInt8.max) {
            storage.append(compose(major: 1, info: 24))
            storage.append(UInt8(truncatingIfNeeded: magnitude))
        } else if magnitude <= UInt64(UInt16.max) {
            storage.append(compose(major: 1, info: 25))
            appendInteger(UInt16(truncatingIfNeeded: magnitude))
        } else if magnitude <= UInt64(UInt32.max) {
            storage.append(compose(major: 1, info: 26))
            appendInteger(UInt32(truncatingIfNeeded: magnitude))
        } else {
            storage.append(compose(major: 1, info: 27))
            appendInteger(magnitude)
        }
    }

    public func writeF32(_ value: Float) throws {
        storage.append(compose(major: 7, info: 26))
        appendInteger(value.bitPattern)
    }

    public func writeF64(_ value: Double) throws {
        storage.append(compose(major: 7, info: 27))
        appendInteger(value.bitPattern)
    }

    public func writeBytes(_ value: [UInt8]) throws {
        try writeRawLen(major: 2, length: checkedLength(value.count))
        storage.append(contentsOf: value)
    }

    public func writeString(_ value: String) throws {
        let utf8 = Array(value.utf8)
        try writeRawLen(major: 3, length: checkedLength(utf8.count))
        storage.append(contentsOf: utf8)
    }

    public func writeArray(_ length: Int) throws {
        try writeRawLen(major: 4, length: checkedLength(length))
    }

    public func writeMap(_ length: Int) throws {
        try writeRawLen(major: 5, length: checkedLength(length))
    }

    public func writeNull() throws {
        storage.append(compose(major: 7, info: 22))
    }

    public func writeStruct<T>(_ value: T) throws where T: RocketPackStruct {
        try T.pack(encoder: self, value: value)
    }

    func writeRawLen(major: UInt8, length: UInt64) throws {
        if length <= 23 {
            storage.append(compose(major: major, info: UInt8(length)))
        } else if length <= UInt64(UInt8.max) {
            storage.append(compose(major: major, info: 24))
            storage.append(UInt8(truncatingIfNeeded: length))
        } else if length <= UInt64(UInt16.max) {
            storage.append(compose(major: major, info: 25))
            appendInteger(UInt16(truncatingIfNeeded: length))
        } else if length <= UInt64(UInt32.max) {
            storage.append(compose(major: major, info: 26))
            appendInteger(UInt32(truncatingIfNeeded: length))
        } else {
            storage.append(compose(major: major, info: 27))
            appendInteger(length)
        }
    }

    private func checkedLength(_ length: Int) throws -> UInt64 {
        guard length >= 0 else {
            throw RocketPackEncoderError.lengthOverflow(length: length)
        }
        return UInt64(length)
    }

    private func appendInteger<T: FixedWidthInteger>(_ value: T) {
        var bigEndian = value.bigEndian
        withUnsafeBytes(of: &bigEndian) { storage.append(contentsOf: $0) }
    }

    @inline(__always)
    private func compose(major: UInt8, info: UInt8) -> UInt8 {
        (major << 5) | (info & 0b0001_1111)
    }
}
