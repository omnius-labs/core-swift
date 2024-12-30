import Foundation
import NIO

public struct RocketMessageWriter {
    var writer: ByteBuffer

    public init(_ writer: inout ByteBuffer) {
        self.writer = writer
    }

    public mutating func putString(_ value: String) {
        Varint.putUInt32(UInt32(value.utf8.count), &self.writer)
        self.writer.writeBytes(value.utf8)
    }

    public mutating func putBytes(_ value: [UInt8]) {
        Varint.putUInt32(UInt32(value.count), &self.writer)
        self.writer.writeBytes(value)
    }

    public mutating func putTimestamp64(_ value: Timestamp64) {
        Varint.putInt64(value.seconds, &self.writer)
    }

    public mutating func putTimestamp96(_ value: Timestamp96) {
        Varint.putInt64(value.seconds, &self.writer)
        Varint.putUInt32(value.nanos, &self.writer)
    }

    public mutating func putBool(_ value: Bool) {
        Varint.putUInt64(value ? 1 : 0, &self.writer)
    }

    public mutating func putUInt8(_ value: UInt8) {
        Varint.putUInt8(value, &self.writer)
    }

    public mutating func putUInt16(_ value: UInt16) {
        Varint.putUInt16(value, &self.writer)
    }

    public mutating func putUInt32(_ value: UInt32) {
        Varint.putUInt32(value, &self.writer)
    }

    public mutating func putUInt64(_ value: UInt64) {
        Varint.putUInt64(value, &self.writer)
    }

    public mutating func putInt8(_ value: Int8) {
        Varint.putInt8(value, &self.writer)
    }

    public mutating func putInt16(_ value: Int16) {
        Varint.putInt16(value, &self.writer)
    }

    public mutating func putInt32(_ value: Int32) {
        Varint.putInt32(value, &self.writer)
    }

    public mutating func putInt64(_ value: Int64) {
        Varint.putInt64(value, &self.writer)
    }

    public mutating func putFloat(_ value: Float) {
        let value = value.bitPattern.littleEndian
        self.putBytes(withUnsafeBytes(of: value) { Array($0) })
    }

    public mutating func putDouble(_ value: Double) {
        let value = value.bitPattern.littleEndian
        self.putBytes(withUnsafeBytes(of: value) { Array($0) })
    }
}
