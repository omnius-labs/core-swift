import Foundation
import NIO

public struct RocketMessageWriter {
    public static func putString(_ value: String, _ writer: inout ByteBuffer) {
        Varint.putUInt32(UInt32(value.utf8.count), &writer)
        writer.writeBytes(value.utf8)
    }

    public static func putBytes(_ value: [UInt8], _ writer: inout ByteBuffer) {
        Varint.putUInt32(UInt32(value.count), &writer)
        writer.writeBytes(value)
    }

    public static func putTimestamp64(_ value: Timestamp64, _ writer: inout ByteBuffer) {
        Varint.putInt64(value.seconds, &writer)
    }

    public static func putTimestamp96(_ value: Timestamp96, _ writer: inout ByteBuffer) {
        Varint.putInt64(value.seconds, &writer)
        Varint.putUInt32(value.nanos, &writer)
    }

    public static func putBool(_ value: Bool, _ writer: inout ByteBuffer) {
        Varint.putUInt64(value ? 1 : 0, &writer)
    }

    public static func putUInt8(_ value: UInt8, _ writer: inout ByteBuffer) {
        Varint.putUInt8(value, &writer)
    }

    public static func putUInt16(_ value: UInt16, _ writer: inout ByteBuffer) {
        Varint.putUInt16(value, &writer)
    }

    public static func putUInt32(_ value: UInt32, _ writer: inout ByteBuffer) {
        Varint.putUInt32(value, &writer)
    }

    public static func putUInt64(_ value: UInt64, _ writer: inout ByteBuffer) {
        Varint.putUInt64(value, &writer)
    }

    public static func putInt8(_ value: Int8, _ writer: inout ByteBuffer) {
        Varint.putInt8(value, &writer)
    }

    public static func putInt16(_ value: Int16, _ writer: inout ByteBuffer) {
        Varint.putInt16(value, &writer)
    }

    public static func putInt32(_ value: Int32, _ writer: inout ByteBuffer) {
        Varint.putInt32(value, &writer)
    }

    public static func putInt64(_ value: Int64, _ writer: inout ByteBuffer) {
        Varint.putInt64(value, &writer)
    }

    public static func putFloat(_ value: Float, _ writer: inout ByteBuffer) {
        let value = value.bitPattern.littleEndian
        self.putBytes(withUnsafeBytes(of: value) { Array($0) }, &writer)
    }

    public static func putDouble(_ value: Double, _ writer: inout ByteBuffer) {
        let value = value.bitPattern.littleEndian
        self.putBytes(withUnsafeBytes(of: value) { Array($0) }, &writer)
    }
}
