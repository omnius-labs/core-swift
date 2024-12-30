import Foundation
import NIO

public struct RocketMessageReader {
    var reader: ByteBuffer

    public init(_ reader: inout ByteBuffer) {
        self.reader = reader
    }

    public mutating func getBytes(_ limit: Int) throws -> [UInt8] {
        let length = try self.getUInt32()
        guard length <= limit else {
            throw RocketMessageError.limitExceeded
        }
        guard length > 0 else {
            return []
        }

        guard let bytes = self.reader.readBytes(length: Int(length)) else {
            throw RocketMessageError.tooSmallBody
        }
        return bytes
    }

    public mutating func getString(_ limit: Int) throws -> String {
        let bytes = try self.getBytes(limit)
        guard let string = String(data: Data(bytes), encoding: .utf8) else {
            throw RocketMessageError.invalidUtf8
        }
        return string
    }

    public mutating func getTimestamp64() throws -> Timestamp64 {
        let seconds = try self.getInt64()
        return Timestamp64(seconds: seconds)
    }

    public mutating func getTimestamp96() throws -> Timestamp96 {
        let seconds = try self.getInt64()
        let nanos = try self.getUInt32()
        return Timestamp96(seconds: seconds, nanos: nanos)
    }

    public mutating func getBool() throws -> Bool {
        let byte = try self.getUInt64()
        return byte != 0
    }

    public mutating func getUInt8() throws -> UInt8 {
        return try Varint.getUInt8(&self.reader)
    }

    public mutating func getUInt16() throws -> UInt16 {
        return try Varint.getUInt16(&self.reader)
    }

    public mutating func getUInt32() throws -> UInt32 {
        return try Varint.getUInt32(&self.reader)
    }

    public mutating func getUInt64() throws -> UInt64 {
        return try Varint.getUInt64(&self.reader)
    }

    public mutating func getInt8() throws -> Int8 {
        return try Varint.getInt8(&self.reader)
    }

    public mutating func getInt16() throws -> Int16 {
        return try Varint.getInt16(&self.reader)
    }

    public mutating func getInt32() throws -> Int32 {
        return try Varint.getInt32(&self.reader)
    }

    public mutating func getInt64() throws -> Int64 {
        return try Varint.getInt64(&self.reader)
    }

    public mutating func getFloat() throws -> Float {
        guard let bytes = self.reader.readBytes(length: Int(4)) else {
            throw RocketMessageError.endOfInput
        }

        let value = UInt32(littleEndian: bytes.withUnsafeBytes { $0.load(as: UInt32.self) })
        return Float(bitPattern: value)
    }

    public mutating func getDouble() throws -> Double {
        guard let bytes = self.reader.readBytes(length: Int(8)) else {
            throw RocketMessageError.endOfInput
        }

        let value = UInt64(littleEndian: bytes.withUnsafeBytes { $0.load(as: UInt64.self) })
        return Double(bitPattern: value)
    }
}
