import Foundation

// https://cborbook.com/part_1/practical_introduction_to_cbor.html

public enum RocketPackDecoderError: Error, Equatable {
    case unexpectedEof
    case mismatchFieldType(position: Int, fieldType: FieldType)
    case lengthOverflow(position: Int)
    case utf8(position: Int, description: String)
    case other(String)
}

public protocol RocketPackDecoder: AnyObject {
    var remaining: Int { get }
    var position: Int { get }

    func currentType() throws -> FieldType

    func readBool() throws -> Bool
    func readU8() throws -> UInt8
    func readU16() throws -> UInt16
    func readU32() throws -> UInt32
    func readU64() throws -> UInt64
    func readI8() throws -> Int8
    func readI16() throws -> Int16
    func readI32() throws -> Int32
    func readI64() throws -> Int64
    func readF32() throws -> Float
    func readF64() throws -> Double
    func readBytes() throws -> [UInt8]
    func readBytesVec() throws -> [UInt8]
    func readString() throws -> String
    func readArray() throws -> UInt64
    func readMap() throws -> UInt64
    func readNull() throws
    func readStruct<T: RocketPackStruct>() throws -> T
    func skipField() throws
}

public final class RocketPackBytesDecoder: RocketPackDecoder {
    private let buffer: [UInt8]
    private var cursor: Int

    public init(bytes: [UInt8]) {
        self.buffer = bytes
        self.cursor = 0
    }

    public convenience init(data: Data) {
        self.init(bytes: [UInt8](data))
    }

    public var remaining: Int {
        buffer.count - cursor
    }

    public var position: Int {
        cursor
    }

    public func currentType() throws -> FieldType {
        let byte = try currentRawByte()
        let (major, info) = decompose(byte)
        return try typeOf(major: major, info: info)
    }

    public func readBool() throws -> Bool {
        let p = cursor
        let byte = try readRawByte()
        let (major, info) = decompose(byte)

        switch (major, info) {
        case (7, 20): return false
        case (7, 21): return true
        default:
            throw try mismatchError(position: p, major: major, info: info)
        }
    }

    public func readU8() throws -> UInt8 {
        let p = cursor
        let byte = try readRawByte()
        let (major, info) = decompose(byte)

        switch (major, info) {
        case (0, 0...23):
            return info
        case (0, 24):
            return try readInteger(UInt8.self)
        default:
            throw try mismatchError(position: p, major: major, info: info)
        }
    }

    public func readU16() throws -> UInt16 {
        let p = cursor
        let byte = try readRawByte()
        let (major, info) = decompose(byte)

        switch (major, info) {
        case (0, 0...23):
            return UInt16(info)
        case (0, 24):
            return UInt16(try readInteger(UInt8.self))
        case (0, 25):
            return try readInteger(UInt16.self)
        default:
            throw try mismatchError(position: p, major: major, info: info)
        }
    }

    public func readU32() throws -> UInt32 {
        let p = cursor
        let byte = try readRawByte()
        let (major, info) = decompose(byte)

        switch (major, info) {
        case (0, 0...23):
            return UInt32(info)
        case (0, 24):
            return UInt32(try readInteger(UInt8.self))
        case (0, 25):
            return UInt32(try readInteger(UInt16.self))
        case (0, 26):
            return try readInteger(UInt32.self)
        default:
            throw try mismatchError(position: p, major: major, info: info)
        }
    }

    public func readU64() throws -> UInt64 {
        let p = cursor
        let byte = try readRawByte()
        let (major, info) = decompose(byte)

        switch (major, info) {
        case (0, 0...23):
            return UInt64(info)
        case (0, 24):
            return UInt64(try readInteger(UInt8.self))
        case (0, 25):
            return UInt64(try readInteger(UInt16.self))
        case (0, 26):
            return UInt64(try readInteger(UInt32.self))
        case (0, 27):
            return try readInteger(UInt64.self)
        default:
            throw try mismatchError(position: p, major: major, info: info)
        }
    }

    public func readI8() throws -> Int8 {
        let p = cursor
        let byte = try readRawByte()
        let (major, info) = decompose(byte)
        let fieldType = try typeOf(major: major, info: info)

        switch major {
        case 0:
            guard let value = try readRawLen(info: info) else {
                throw RocketPackDecoderError.mismatchFieldType(position: p, fieldType: fieldType)
            }
            guard value <= UInt64(Int8.max) else {
                throw RocketPackDecoderError.mismatchFieldType(position: p, fieldType: fieldType)
            }
            guard let result = Int8(exactly: Int64(value)) else {
                throw RocketPackDecoderError.mismatchFieldType(position: p, fieldType: fieldType)
            }
            return result
        case 1:
            guard let magnitude = try readRawLen(info: info) else {
                throw RocketPackDecoderError.mismatchFieldType(position: p, fieldType: fieldType)
            }
            guard magnitude <= UInt64(Int8.max) else {
                throw RocketPackDecoderError.mismatchFieldType(position: p, fieldType: fieldType)
            }
            let signed = -1 - Int64(magnitude)
            guard let value = Int8(exactly: signed) else {
                throw RocketPackDecoderError.mismatchFieldType(position: p, fieldType: fieldType)
            }
            return value
        default:
            throw RocketPackDecoderError.mismatchFieldType(position: p, fieldType: fieldType)
        }
    }

    public func readI16() throws -> Int16 {
        let p = cursor
        let byte = try readRawByte()
        let (major, info) = decompose(byte)
        let fieldType = try typeOf(major: major, info: info)

        switch major {
        case 0:
            guard let value = try readRawLen(info: info) else {
                throw RocketPackDecoderError.mismatchFieldType(position: p, fieldType: fieldType)
            }
            guard value <= UInt64(Int16.max) else {
                throw RocketPackDecoderError.mismatchFieldType(position: p, fieldType: fieldType)
            }
            guard let result = Int16(exactly: Int64(value)) else {
                throw RocketPackDecoderError.mismatchFieldType(position: p, fieldType: fieldType)
            }
            return result
        case 1:
            guard let magnitude = try readRawLen(info: info) else {
                throw RocketPackDecoderError.mismatchFieldType(position: p, fieldType: fieldType)
            }
            guard magnitude <= UInt64(Int16.max) else {
                throw RocketPackDecoderError.mismatchFieldType(position: p, fieldType: fieldType)
            }
            let signed = -1 - Int64(magnitude)
            guard let value = Int16(exactly: signed) else {
                throw RocketPackDecoderError.mismatchFieldType(position: p, fieldType: fieldType)
            }
            return value
        default:
            throw RocketPackDecoderError.mismatchFieldType(position: p, fieldType: fieldType)
        }
    }

    public func readI32() throws -> Int32 {
        let p = cursor
        let byte = try readRawByte()
        let (major, info) = decompose(byte)
        let fieldType = try typeOf(major: major, info: info)

        switch major {
        case 0:
            guard let value = try readRawLen(info: info) else {
                throw RocketPackDecoderError.mismatchFieldType(position: p, fieldType: fieldType)
            }
            guard value <= UInt64(Int32.max) else {
                throw RocketPackDecoderError.mismatchFieldType(position: p, fieldType: fieldType)
            }
            guard let result = Int32(exactly: Int64(value)) else {
                throw RocketPackDecoderError.mismatchFieldType(position: p, fieldType: fieldType)
            }
            return result
        case 1:
            guard let magnitude = try readRawLen(info: info) else {
                throw RocketPackDecoderError.mismatchFieldType(position: p, fieldType: fieldType)
            }
            guard magnitude <= UInt64(Int32.max) else {
                throw RocketPackDecoderError.mismatchFieldType(position: p, fieldType: fieldType)
            }
            let signed = -1 - Int64(magnitude)
            guard let value = Int32(exactly: signed) else {
                throw RocketPackDecoderError.mismatchFieldType(position: p, fieldType: fieldType)
            }
            return value
        default:
            throw RocketPackDecoderError.mismatchFieldType(position: p, fieldType: fieldType)
        }
    }

    public func readI64() throws -> Int64 {
        let p = cursor
        let byte = try readRawByte()
        let (major, info) = decompose(byte)
        let fieldType = try typeOf(major: major, info: info)

        switch major {
        case 0:
            guard let value = try readRawLen(info: info) else {
                throw RocketPackDecoderError.mismatchFieldType(position: p, fieldType: fieldType)
            }
            guard value <= UInt64(Int64.max) else {
                throw RocketPackDecoderError.mismatchFieldType(position: p, fieldType: fieldType)
            }
            return Int64(value)
        case 1:
            guard let magnitude = try readRawLen(info: info) else {
                throw RocketPackDecoderError.mismatchFieldType(position: p, fieldType: fieldType)
            }
            guard magnitude <= UInt64(Int64.max) else {
                throw RocketPackDecoderError.mismatchFieldType(position: p, fieldType: fieldType)
            }
            let signed = -1 - Int64(magnitude)
            return signed
        default:
            throw RocketPackDecoderError.mismatchFieldType(position: p, fieldType: fieldType)
        }
    }

    public func readF32() throws -> Float {
        let p = cursor
        let byte = try readRawByte()
        let (major, info) = decompose(byte)
        guard (major, info) == (7, 26) else {
            throw try mismatchError(position: p, major: major, info: info)
        }
        let bits: UInt32 = try readInteger(UInt32.self)
        return Float(bitPattern: bits)
    }

    public func readF64() throws -> Double {
        let p = cursor
        let byte = try readRawByte()
        let (major, info) = decompose(byte)
        guard (major, info) == (7, 27) else {
            throw try mismatchError(position: p, major: major, info: info)
        }
        let bits: UInt64 = try readInteger(UInt64.self)
        return Double(bitPattern: bits)
    }

    public func readBytes() throws -> [UInt8] {
        let p = cursor
        let byte = try readRawByte()
        let (major, info) = decompose(byte)
        guard major == 2 else {
            throw try mismatchError(position: p, major: major, info: info)
        }
        guard let len = try readRawLen(info: info) else {
            throw try mismatchError(position: p, major: major, info: info)
        }
        let count = try convertToLength(len, position: p)
        return try readRawBytes(count: count)
    }

    public func readBytesVec() throws -> [UInt8] {
        return try readBytes()
    }

    public func readString() throws -> String {
        let p = cursor
        let byte = try readRawByte()
        let (major, info) = decompose(byte)
        guard major == 3 else {
            throw try mismatchError(position: p, major: major, info: info)
        }
        guard let len = try readRawLen(info: info) else {
            throw try mismatchError(position: p, major: major, info: info)
        }
        let count = try convertToLength(len, position: p)
        let bytes = try readRawBytes(count: count)
        if let string = String(bytes: bytes, encoding: .utf8) {
            return string
        }
        throw RocketPackDecoderError.utf8(position: p, description: "invalid UTF-8 sequence")
    }

    public func readArray() throws -> UInt64 {
        let p = cursor
        let byte = try readRawByte()
        let (major, info) = decompose(byte)
        guard major == 4 else {
            throw try mismatchError(position: p, major: major, info: info)
        }
        guard let len = try readRawLen(info: info) else {
            throw try mismatchError(position: p, major: major, info: info)
        }
        return len
    }

    public func readMap() throws -> UInt64 {
        let p = cursor
        let byte = try readRawByte()
        let (major, info) = decompose(byte)
        guard major == 5 else {
            throw try mismatchError(position: p, major: major, info: info)
        }
        guard let len = try readRawLen(info: info) else {
            throw try mismatchError(position: p, major: major, info: info)
        }
        return len
    }

    public func readNull() throws {
        let p = cursor
        let byte = try readRawByte()
        let (major, info) = decompose(byte)
        guard (major, info) == (7, 22) else {
            throw try mismatchError(position: p, major: major, info: info)
        }
    }

    public func readStruct<T>() throws -> T where T: RocketPackStruct {
        return try T.unpack(decoder: self)
    }

    public func skipField() throws {
        var remainingFields: UInt64 = 1

        while remainingFields > 0 {
            let p = cursor
            let byte = try readRawByte()
            let (major, info) = decompose(byte)

            let additional: UInt64?
            switch major {
            case 0, 1:
                switch info {
                case 0...23:
                    additional = 0
                case 24:
                    additional = 1
                case 25:
                    additional = 2
                case 26:
                    additional = 4
                case 27:
                    additional = 8
                case 28:
                    additional = 16
                default:
                    additional = nil
                }
            case 2, 3:
                additional = try readRawLen(info: info)
            case 4:
                guard let count = try readRawLen(info: info) else {
                    throw try mismatchError(position: p, major: major, info: info)
                }
                let addition = remainingFields.addingReportingOverflow(count)
                if addition.overflow {
                    throw RocketPackDecoderError.lengthOverflow(position: p)
                }
                remainingFields = addition.partialValue
                additional = 0
            case 5:
                guard let count = try readRawLen(info: info) else {
                    throw try mismatchError(position: p, major: major, info: info)
                }
                let doubled = count.multipliedReportingOverflow(by: 2)
                if doubled.overflow {
                    throw RocketPackDecoderError.lengthOverflow(position: p)
                }
                let addition = remainingFields.addingReportingOverflow(doubled.partialValue)
                if addition.overflow {
                    throw RocketPackDecoderError.lengthOverflow(position: p)
                }
                remainingFields = addition.partialValue
                additional = 0
            case 7:
                switch info {
                case 20, 21:
                    additional = 0
                case 25:
                    additional = 2
                case 26:
                    additional = 4
                case 27:
                    additional = 8
                default:
                    additional = nil
                }
            default:
                additional = nil
            }

            guard let len = additional else {
                throw try mismatchError(position: p, major: major, info: info)
            }

            let byteCount = try convertToLength(len, position: p)
            try skipRawBytes(count: byteCount)
            remainingFields -= 1
        }
    }

    func readRawLen(info: UInt8) throws -> UInt64? {
        switch info {
        case 0...23:
            return UInt64(info)
        case 24:
            let value: UInt8 = try readInteger(UInt8.self)
            return UInt64(value)
        case 25:
            let value: UInt16 = try readInteger(UInt16.self)
            return UInt64(value)
        case 26:
            let value: UInt32 = try readInteger(UInt32.self)
            return UInt64(value)
        case 27:
            let value: UInt64 = try readInteger(UInt64.self)
            return value
        default:
            return nil
        }
    }

    private func typeOf(major: UInt8, info: UInt8) throws -> FieldType {
        switch (major, info) {
        case (0, 0...23): return .u8
        case (0, 24): return .u8
        case (0, 25): return .u16
        case (0, 26): return .u32
        case (0, 27): return .u64
        case (1, 0...23): return .u8
        case (1, 24...28):
            let next = try peekRawByte()
            if (next & 0x80) != 0x80 {
                switch info {
                case 24: return .i8
                case 25: return .i16
                case 26: return .i32
                case 27: return .i64
                default: break
                }
            } else {
                switch info {
                case 24: return .i16
                case 25: return .i32
                case 26: return .i64
                default: break
                }
            }
        case (2, _): return .bytes
        case (3, _): return .string
        case (4, _): return .array
        case (5, _): return .map
        case (7, 20...21): return .bool
        case (7, 25): return .f16
        case (7, 26): return .f32
        case (7, 27): return .f64
        default: break
        }
        return .unknown(major: major, info: info)
    }

    private func mismatchError(position: Int, major: UInt8, info: UInt8) throws -> RocketPackDecoderError {
        .mismatchFieldType(position: position, fieldType: try typeOf(major: major, info: info))
    }

    private func convertToLength(_ value: UInt64, position: Int) throws -> Int {
        guard let length = Int(exactly: value) else {
            throw RocketPackDecoderError.lengthOverflow(position: position)
        }
        return length
    }

    private func decompose(_ value: UInt8) -> (UInt8, UInt8) {
        let major = value >> 5
        let info = value & 0b0001_1111
        return (major, info)
    }

    private func currentRawByte() throws -> UInt8 {
        guard cursor < buffer.count else {
            throw RocketPackDecoderError.unexpectedEof
        }
        return buffer[cursor]
    }

    private func peekRawByte() throws -> UInt8 {
        guard cursor + 1 < buffer.count else {
            throw RocketPackDecoderError.unexpectedEof
        }
        return buffer[cursor + 1]
    }

    private func readRawByte() throws -> UInt8 {
        guard cursor < buffer.count else {
            throw RocketPackDecoderError.unexpectedEof
        }
        let byte = buffer[cursor]
        cursor += 1
        return byte
    }

    private func readInteger<T: FixedWidthInteger>(_ type: T.Type) throws -> T {
        let count = MemoryLayout<T>.size
        let bytes = try readRawBytes(count: count)
        let raw = bytes.withUnsafeBytes { ptr in
            ptr.load(as: T.self)
        }
        return T(bigEndian: raw)
    }

    private func readRawBytes(count: Int) throws -> [UInt8] {
        guard count <= remaining else {
            throw RocketPackDecoderError.unexpectedEof
        }
        let end = cursor + count
        let slice = Array(buffer[cursor..<end])
        cursor = end
        return slice
    }

    private func skipRawBytes(count: Int) throws {
        guard count <= remaining else {
            throw RocketPackDecoderError.unexpectedEof
        }
        cursor += count
    }
}
