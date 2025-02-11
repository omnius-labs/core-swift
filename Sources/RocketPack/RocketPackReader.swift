import Foundation
import NIO

public struct RocketMessageReader {
    public static func getBytes(_ reader: inout ByteBuffer, _ limit: Int) throws -> [UInt8] {
        let length = try self.getUInt32(&reader)
        guard length <= limit else {
            throw RocketMessageError.limitExceeded
        }
        guard length > 0 else {
            return []
        }

        guard let bytes = reader.readBytes(length: Int(length)) else {
            throw RocketMessageError.tooSmallBody
        }
        return bytes
    }

    public static func getString(_ reader: inout ByteBuffer, _ limit: Int) throws -> String {
        let bytes = try self.getBytes(&reader, limit)
        guard let string = String(data: Data(bytes), encoding: .utf8) else {
            throw RocketMessageError.invalidUtf8
        }
        return string
    }

    public static func getTimestamp64(_ reader: inout ByteBuffer) throws -> Timestamp64 {
        let seconds = try self.getInt64(&reader)
        return Timestamp64(seconds: seconds)
    }

    public static func getTimestamp96(_ reader: inout ByteBuffer) throws -> Timestamp96 {
        let seconds = try self.getInt64(&reader)
        let nanos = try self.getUInt32(&reader)
        return Timestamp96(seconds: seconds, nanos: nanos)
    }

    public static func getBool(_ reader: inout ByteBuffer) throws -> Bool {
        let byte = try self.getUInt64(&reader)
        return byte != 0
    }

    public static func getUInt8(_ reader: inout ByteBuffer) throws -> UInt8 {
        return try Varint.getUInt8(&reader)
    }

    public static func getUInt16(_ reader: inout ByteBuffer) throws -> UInt16 {
        return try Varint.getUInt16(&reader)
    }

    public static func getUInt32(_ reader: inout ByteBuffer) throws -> UInt32 {
        return try Varint.getUInt32(&reader)
    }

    public static func getUInt64(_ reader: inout ByteBuffer) throws -> UInt64 {
        return try Varint.getUInt64(&reader)
    }

    public static func getInt8(_ reader: inout ByteBuffer) throws -> Int8 {
        return try Varint.getInt8(&reader)
    }

    public static func getInt16(_ reader: inout ByteBuffer) throws -> Int16 {
        return try Varint.getInt16(&reader)
    }

    public static func getInt32(_ reader: inout ByteBuffer) throws -> Int32 {
        return try Varint.getInt32(&reader)
    }

    public static func getInt64(_ reader: inout ByteBuffer) throws -> Int64 {
        return try Varint.getInt64(&reader)
    }

    public static func getFloat(_ reader: inout ByteBuffer) throws -> Float {
        guard let bytes = reader.readBytes(length: Int(4)) else {
            throw RocketMessageError.endOfInput
        }

        let value = UInt32(littleEndian: bytes.withUnsafeBytes { $0.load(as: UInt32.self) })
        return Float(bitPattern: value)
    }

    public static func getDouble(_ reader: inout ByteBuffer) throws -> Double {
        guard let bytes = reader.readBytes(length: Int(8)) else {
            throw RocketMessageError.endOfInput
        }

        let value = UInt64(littleEndian: bytes.withUnsafeBytes { $0.load(as: UInt64.self) })
        return Double(bitPattern: value)
    }
}
