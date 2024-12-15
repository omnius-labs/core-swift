import Foundation

public struct Varint {
    static let MIN_INT7: UInt8 = 0x00  // 0
    static let MAX_INT7: UInt8 = 0x7F  // 127

    static let INT8_CODE: UInt8 = 0x80
    static let INT16_CODE: UInt8 = 0x81
    static let INT32_CODE: UInt8 = 0x82
    static let INT64_CODE: UInt8 = 0x83

    public static func putUInt8(_ value: UInt8, _ writer: inout Data) {
        if value <= MAX_INT7 {
            writer.append(value)
        } else {
            writer.append(INT8_CODE)
            writer.append(value)
        }
    }

    public static func putUInt16(_ value: UInt16, _ writer: inout Data) {
        if value <= UInt16(MAX_INT7) {
            writer.append(UInt8(value))
        } else if value <= UInt16(UInt8.max) {
            writer.append(INT8_CODE)
            writer.append(UInt8(value))
        } else {
            writer.append(INT16_CODE)
            writer.append(contentsOf: withUnsafeBytes(of: UInt16(value).littleEndian, Array.init))
        }
    }

    static func putUInt32(_ value: UInt32, _ writer: inout Data) {
        if value <= UInt32(MAX_INT7) {
            writer.append(UInt8(value))
        } else if value <= UInt32(UInt8.max) {
            writer.append(INT8_CODE)
            writer.append(UInt8(value))
        } else if value <= UInt32(UInt16.max) {
            writer.append(INT16_CODE)
            writer.append(contentsOf: withUnsafeBytes(of: UInt16(value).littleEndian, Array.init))
        } else {
            writer.append(INT32_CODE)
            writer.append(contentsOf: withUnsafeBytes(of: value.littleEndian, Array.init))
        }
    }

    static func putUInt64(_ value: UInt64, _ writer: inout Data) {
        if value <= UInt64(MAX_INT7) {
            writer.append(UInt8(value))
        } else if value <= UInt64(UInt8.max) {
            writer.append(INT8_CODE)
            writer.append(UInt8(value))
        } else if value <= UInt64(UInt16.max) {
            writer.append(INT16_CODE)
            writer.append(contentsOf: withUnsafeBytes(of: UInt16(value).littleEndian, Array.init))
        } else if value <= UInt64(UInt32.max) {
            writer.append(INT32_CODE)
            writer.append(contentsOf: withUnsafeBytes(of: UInt32(value).littleEndian, Array.init))
        } else {
            writer.append(INT64_CODE)
            writer.append(contentsOf: withUnsafeBytes(of: value.littleEndian, Array.init))
        }
    }

    static func putInt8(_ value: Int8, _ writer: inout Data) {
        let value = UInt8(bitPattern: value)
        let encodedValue = (value << 1) ^ (value >> 7)
        putUInt8(encodedValue, &writer)
    }

    static func putInt16(_ value: Int16, _ writer: inout Data) {
        let value = UInt16(bitPattern: value)
        let encodedValue = (value << 1) ^ (value >> 15)
        putUInt16(encodedValue, &writer)
    }

    static func putInt32(_ value: Int32, _ writer: inout Data) {
        let value = UInt32(bitPattern: value)
        let encodedValue = (value << 1) ^ (value >> 31)
        putUInt32(encodedValue, &writer)
    }

    static func putInt64(_ value: Int64, _ writer: inout Data) {
        let value = UInt64(bitPattern: value)
        let encodedValue = (value << 1) ^ (value >> 63)
        putUInt64(encodedValue, &writer)
    }

    public static func getUInt8(_ reader: inout Data) throws -> UInt8 {
        guard reader.count > 0 else {
            throw VarintError.endOfInput
        }

        let head = reader.removeFirst()

        if (head & 0x80) == 0 {
            return head
        } else if head == INT8_CODE {
            guard reader.count >= 1 else {
                throw VarintError.tooSmallBody
            }
            return reader.removeFirst()
        } else {
            throw VarintError.invalidHeader
        }
    }

    static func getUInt16(_ reader: inout Data) throws -> UInt16 {
        guard reader.count > 0 else {
            throw VarintError.endOfInput
        }

        let head = reader.removeFirst()

        if (head & 0x80) == 0 {
            return UInt16(head)
        } else if head == INT8_CODE {
            guard reader.count >= 1 else {
                throw VarintError.tooSmallBody
            }
            return UInt16(reader.removeFirst())
        } else if head == INT16_CODE {
            guard reader.count >= 2 else {
                throw VarintError.tooSmallBody
            }
            let bytes = reader.prefix(2)
            reader.removeFirst(2)
            return bytes.reversed().reduce(0) { $0 << 8 | UInt16($1) }
        } else {
            throw VarintError.invalidHeader
        }
    }

    static func getUInt32(_ reader: inout Data) throws -> UInt32 {
        guard reader.count > 0 else {
            throw VarintError.endOfInput
        }

        let head = reader.removeFirst()

        if (head & 0x80) == 0 {
            return UInt32(head)
        } else if head == INT8_CODE {
            guard reader.count >= 1 else {
                throw VarintError.tooSmallBody
            }
            return UInt32(reader.removeFirst())
        } else if head == INT16_CODE {
            guard reader.count >= 2 else {
                throw VarintError.tooSmallBody
            }
            let bytes = reader.prefix(2)
            reader.removeFirst(2)
            return bytes.reversed().reduce(0) { $0 << 8 | UInt32($1) }
        } else if head == INT32_CODE {
            guard reader.count >= 4 else {
                throw VarintError.tooSmallBody
            }
            let bytes = reader.prefix(4)
            reader.removeFirst(4)
            return bytes.reversed().reduce(0) { $0 << 8 | UInt32($1) }
        } else {
            throw VarintError.invalidHeader
        }
    }

    static func getUInt64(_ reader: inout Data) throws -> UInt64 {
        guard reader.count > 0 else {
            throw VarintError.endOfInput
        }

        let head = reader.removeFirst()

        if (head & 0x80) == 0 {
            return UInt64(head)
        } else if head == INT8_CODE {
            guard reader.count >= 1 else {
                throw VarintError.tooSmallBody
            }
            return UInt64(reader.removeFirst())
        } else if head == INT16_CODE {
            guard reader.count >= 2 else {
                throw VarintError.tooSmallBody
            }
            let bytes = reader.prefix(2)
            reader.removeFirst(2)
            return bytes.reversed().reduce(0) { $0 << 8 | UInt64($1) }
        } else if head == INT32_CODE {
            guard reader.count >= 4 else {
                throw VarintError.tooSmallBody
            }
            let bytes = reader.prefix(4)
            reader.removeFirst(4)
            return bytes.reversed().reduce(0) { $0 << 8 | UInt64($1) }
        } else if head == INT64_CODE {
            guard reader.count >= 8 else {
                throw VarintError.tooSmallBody
            }
            let bytes = reader.prefix(8)
            reader.removeFirst(8)
            return bytes.reversed().reduce(0) { $0 << 8 | UInt64($1) }
        } else {
            throw VarintError.invalidHeader
        }
    }

    static func getInt8(_ reader: inout Data) throws -> Int8 {
        let value = try getUInt8(&reader)
        let decodedValue = (value << 7) ^ (value >> 1)
        return Int8(bitPattern: decodedValue)
    }

    static func getInt16(_ reader: inout Data) throws -> Int16 {
        let value = try getUInt16(&reader)
        let decodedValue = (value << 15) ^ (value >> 1)
        return Int16(bitPattern: decodedValue)
    }

    static func getInt32(_ reader: inout Data) throws -> Int32 {
        let value = try getUInt32(&reader)
        let decodedValue = (value << 31) ^ (value >> 1)
        return Int32(bitPattern: decodedValue)
    }

    static func getInt64(_ reader: inout Data) throws -> Int64 {
        let value = try getUInt64(&reader)
        let decodedValue = (value << 63) ^ (value >> 1)
        return Int64(bitPattern: decodedValue)
    }
}
