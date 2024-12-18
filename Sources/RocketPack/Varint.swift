import Foundation
import NIO

public struct Varint {
    static let MIN_INT7: UInt8 = 0x00  // 0
    static let MAX_INT7: UInt8 = 0x7F  // 127

    static let INT8_CODE: UInt8 = 0x80
    static let INT16_CODE: UInt8 = 0x81
    static let INT32_CODE: UInt8 = 0x82
    static let INT64_CODE: UInt8 = 0x83

    public static func putUInt8(_ value: UInt8, _ writer: inout ByteBuffer) {
        if value <= MAX_INT7 {
            writer.writeInteger(value)
        } else {
            writer.writeInteger(INT8_CODE)
            writer.writeInteger(value)
        }
    }

    public static func putUInt16(_ value: UInt16, _ writer: inout ByteBuffer) {
        if value <= UInt16(MAX_INT7) {
            writer.writeInteger(UInt8(value))
        } else if value <= UInt16(UInt8.max) {
            writer.writeInteger(INT8_CODE)
            writer.writeInteger(UInt8(value))
        } else {
            writer.writeInteger(INT16_CODE)
            writer.writeBytes(withUnsafeBytes(of: UInt16(value).littleEndian, Array.init))
        }
    }

    static func putUInt32(_ value: UInt32, _ writer: inout ByteBuffer) {
        if value <= UInt32(MAX_INT7) {
            writer.writeInteger(UInt8(value))
        } else if value <= UInt32(UInt8.max) {
            writer.writeInteger(INT8_CODE)
            writer.writeInteger(UInt8(value))
        } else if value <= UInt32(UInt16.max) {
            writer.writeInteger(INT16_CODE)
            writer.writeBytes(withUnsafeBytes(of: UInt16(value).littleEndian, Array.init))
        } else {
            writer.writeInteger(INT32_CODE)
            writer.writeBytes(withUnsafeBytes(of: value.littleEndian, Array.init))
        }
    }

    static func putUInt64(_ value: UInt64, _ writer: inout ByteBuffer) {
        if value <= UInt64(MAX_INT7) {
            writer.writeInteger(UInt8(value))
        } else if value <= UInt64(UInt8.max) {
            writer.writeInteger(INT8_CODE)
            writer.writeInteger(UInt8(value))
        } else if value <= UInt64(UInt16.max) {
            writer.writeInteger(INT16_CODE)
            writer.writeBytes(withUnsafeBytes(of: UInt16(value).littleEndian, Array.init))
        } else if value <= UInt64(UInt32.max) {
            writer.writeInteger(INT32_CODE)
            writer.writeBytes(withUnsafeBytes(of: UInt32(value).littleEndian, Array.init))
        } else {
            writer.writeInteger(INT64_CODE)
            writer.writeBytes(withUnsafeBytes(of: value.littleEndian, Array.init))
        }
    }

    static func putInt8(_ value: Int8, _ writer: inout ByteBuffer) {
        let value = UInt8(bitPattern: value)
        let encodedValue = (value << 1) ^ (value >> 7)
        putUInt8(encodedValue, &writer)
    }

    static func putInt16(_ value: Int16, _ writer: inout ByteBuffer) {
        let value = UInt16(bitPattern: value)
        let encodedValue = (value << 1) ^ (value >> 15)
        putUInt16(encodedValue, &writer)
    }

    static func putInt32(_ value: Int32, _ writer: inout ByteBuffer) {
        let value = UInt32(bitPattern: value)
        let encodedValue = (value << 1) ^ (value >> 31)
        putUInt32(encodedValue, &writer)
    }

    static func putInt64(_ value: Int64, _ writer: inout ByteBuffer) {
        let value = UInt64(bitPattern: value)
        let encodedValue = (value << 1) ^ (value >> 63)
        putUInt64(encodedValue, &writer)
    }

    public static func getUInt8(_ reader: inout ByteBuffer) throws -> UInt8 {
        guard let head: UInt8 = reader.readInteger() else {
            throw VarintError.endOfInput
        }

        if (head & 0x80) == 0 {
            return head
        } else if head == INT8_CODE {
            guard let value: UInt8 = reader.readInteger() else {
                throw VarintError.tooSmallBody
            }
            return value
        } else {
            throw VarintError.invalidHeader
        }
    }

    static func getUInt16(_ reader: inout ByteBuffer) throws -> UInt16 {
        guard let head: UInt8 = reader.readInteger() else {
            throw VarintError.endOfInput
        }

        if (head & 0x80) == 0 {
            return UInt16(head)
        } else if head == INT8_CODE {
            guard let value: UInt8 = reader.readInteger() else {
                throw VarintError.tooSmallBody
            }
            return UInt16(value)
        } else if head == INT16_CODE {
            guard let bytes = reader.readBytes(length: 2) else {
                throw VarintError.tooSmallBody
            }
            return bytes.reversed().reduce(0) { $0 << 8 | UInt16($1) }
        } else {
            throw VarintError.invalidHeader
        }
    }

    static func getUInt32(_ reader: inout ByteBuffer) throws -> UInt32 {
        guard let head: UInt8 = reader.readInteger() else {
            throw VarintError.endOfInput
        }

        if (head & 0x80) == 0 {
            return UInt32(head)
        } else if head == INT8_CODE {
            guard let value: UInt8 = reader.readInteger() else {
                throw VarintError.tooSmallBody
            }
            return UInt32(value)
        } else if head == INT16_CODE {
            guard let bytes = reader.readBytes(length: 2) else {
                throw VarintError.tooSmallBody
            }
            return bytes.reversed().reduce(0) { $0 << 8 | UInt32($1) }
        } else if head == INT32_CODE {
            guard let bytes = reader.readBytes(length: 4) else {
                throw VarintError.tooSmallBody
            }
            return bytes.reversed().reduce(0) { $0 << 8 | UInt32($1) }
        } else {
            throw VarintError.invalidHeader
        }
    }

    static func getUInt64(_ reader: inout ByteBuffer) throws -> UInt64 {
        guard let head: UInt8 = reader.readInteger() else {
            throw VarintError.endOfInput
        }

        if (head & 0x80) == 0 {
            return UInt64(head)
        } else if head == INT8_CODE {
            guard let value: UInt8 = reader.readInteger() else {
                throw VarintError.tooSmallBody
            }
            return UInt64(value)
        } else if head == INT16_CODE {
            guard let bytes = reader.readBytes(length: 2) else {
                throw VarintError.tooSmallBody
            }
            return bytes.reversed().reduce(0) { $0 << 8 | UInt64($1) }
        } else if head == INT32_CODE {
            guard let bytes = reader.readBytes(length: 4) else {
                throw VarintError.tooSmallBody
            }
            return bytes.reversed().reduce(0) { $0 << 8 | UInt64($1) }
        } else if head == INT64_CODE {
            guard let bytes = reader.readBytes(length: 8) else {
                throw VarintError.tooSmallBody
            }
            return bytes.reversed().reduce(0) { $0 << 8 | UInt64($1) }
        } else {
            throw VarintError.invalidHeader
        }
    }

    static func getInt8(_ reader: inout ByteBuffer) throws -> Int8 {
        let value = try getUInt8(&reader)
        let decodedValue = (value << 7) ^ (value >> 1)
        return Int8(bitPattern: decodedValue)
    }

    static func getInt16(_ reader: inout ByteBuffer) throws -> Int16 {
        let value = try getUInt16(&reader)
        let decodedValue = (value << 15) ^ (value >> 1)
        return Int16(bitPattern: decodedValue)
    }

    static func getInt32(_ reader: inout ByteBuffer) throws -> Int32 {
        let value = try getUInt32(&reader)
        let decodedValue = (value << 31) ^ (value >> 1)
        return Int32(bitPattern: decodedValue)
    }

    static func getInt64(_ reader: inout ByteBuffer) throws -> Int64 {
        let value = try getUInt64(&reader)
        let decodedValue = (value << 63) ^ (value >> 1)
        return Int64(bitPattern: decodedValue)
    }
}
