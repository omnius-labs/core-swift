import Base
import Foundation
import NIO
import Testing

@testable import RocketPack

struct Constants {
    public static let INT8_CODE: UInt8 = 0x80
    public static let INT16_CODE: UInt8 = 0x81
    public static let INT32_CODE: UInt8 = 0x82
    public static let INT64_CODE: UInt8 = 0x83
}

@Test func emptyDataGetTest() throws {
    var buf = ByteBuffer()

    // 8
    #expect(throws: VarintError.endOfInput) {
        _ = try Varint.getUInt8(&buf)
    }
    #expect(throws: VarintError.endOfInput) {
        _ = try Varint.getInt8(&buf)
    }

    // 16
    #expect(throws: VarintError.endOfInput) {
        _ = try Varint.getUInt16(&buf)
    }
    #expect(throws: VarintError.endOfInput) {
        _ = try Varint.getInt16(&buf)
    }

    // 32
    #expect(throws: VarintError.endOfInput) {
        _ = try Varint.getUInt32(&buf)
    }
    #expect(throws: VarintError.endOfInput) {
        _ = try Varint.getInt32(&buf)
    }

    // 64
    #expect(throws: VarintError.endOfInput) {
        _ = try Varint.getUInt64(&buf)
    }
    #expect(throws: VarintError.endOfInput) {
        _ = try Varint.getInt64(&buf)
    }
}

@Test func brokenHeaderDataGetTest() throws {
    // 8
    do {
        var buf = ByteBuffer()
        buf.writeInteger(Constants.INT16_CODE)
        #expect(throws: VarintError.invalidHeader) {
            var buf = buf
            _ = try Varint.getUInt8(&buf)
        }
        #expect(throws: VarintError.invalidHeader) {
            var buf = buf
            _ = try Varint.getInt8(&buf)
        }
    }

    // 16
    do {
        var buf = ByteBuffer()
        buf.writeInteger(Constants.INT32_CODE)
        #expect(throws: VarintError.invalidHeader) {
            var buf = buf
            _ = try Varint.getUInt16(&buf)
        }
        #expect(throws: VarintError.invalidHeader) {
            var buf = buf
            _ = try Varint.getInt16(&buf)
        }
    }

    // 32
    do {
        var buf = ByteBuffer()
        buf.writeInteger(Constants.INT64_CODE)
        #expect(throws: VarintError.invalidHeader) {
            var buf = buf
            _ = try Varint.getUInt32(&buf)
        }
        #expect(throws: VarintError.invalidHeader) {
            var buf = buf
            _ = try Varint.getInt32(&buf)
        }
    }

    // 64
    do {
        var buf = ByteBuffer()
        buf.writeInteger(Constants.INT64_CODE + 1)
        #expect(throws: VarintError.invalidHeader) {
            var buf = buf
            _ = try Varint.getUInt32(&buf)
        }
        #expect(throws: VarintError.invalidHeader) {
            var buf = buf
            _ = try Varint.getInt32(&buf)
        }
    }
}

@Test func brokenBodyDataGetTest() throws {
    // INT8_CODE
    do {
        var buf = ByteBuffer()
        buf.writeInteger(Constants.INT8_CODE)

        // 8
        #expect(throws: VarintError.tooSmall) {
            var buf = buf
            _ = try Varint.getUInt8(&buf)
        }
        #expect(throws: VarintError.tooSmall) {
            var buf = buf
            _ = try Varint.getInt8(&buf)
        }

        // 16
        #expect(throws: VarintError.tooSmall) {
            var buf = buf
            _ = try Varint.getUInt16(&buf)
        }
        #expect(throws: VarintError.tooSmall) {
            var buf = buf
            _ = try Varint.getInt16(&buf)
        }

        // 32
        #expect(throws: VarintError.tooSmall) {
            var buf = buf
            _ = try Varint.getUInt32(&buf)
        }
        #expect(throws: VarintError.tooSmall) {
            var buf = buf
            _ = try Varint.getInt32(&buf)
        }

        // 64
        #expect(throws: VarintError.tooSmall) {
            var buf = buf
            _ = try Varint.getUInt64(&buf)
        }
        #expect(throws: VarintError.tooSmall) {
            var buf = buf
            _ = try Varint.getInt64(&buf)
        }
    }

    // INT16_CODE
    do {
        var buf = ByteBuffer()
        buf.writeInteger(Constants.INT16_CODE)

        // 16
        #expect(throws: VarintError.tooSmall) {
            var buf = buf
            _ = try Varint.getUInt16(&buf)
        }
        #expect(throws: VarintError.tooSmall) {
            var buf = buf
            _ = try Varint.getInt16(&buf)
        }

        // 32
        #expect(throws: VarintError.tooSmall) {
            var buf = buf
            _ = try Varint.getUInt32(&buf)
        }
        #expect(throws: VarintError.tooSmall) {
            var buf = buf
            _ = try Varint.getInt32(&buf)
        }

        // 64
        #expect(throws: VarintError.tooSmall) {
            var buf = buf
            _ = try Varint.getUInt64(&buf)
        }
        #expect(throws: VarintError.tooSmall) {
            var buf = buf
            _ = try Varint.getInt64(&buf)
        }
    }

    // INT32_CODE
    do {
        var buf = ByteBuffer()
        buf.writeInteger(Constants.INT32_CODE)

        // 32
        #expect(throws: VarintError.tooSmall) {
            var buf = buf
            _ = try Varint.getUInt32(&buf)
        }
        #expect(throws: VarintError.tooSmall) {
            var buf = buf
            _ = try Varint.getInt32(&buf)
        }

        // 64
        #expect(throws: VarintError.tooSmall) {
            var buf = buf
            _ = try Varint.getUInt64(&buf)
        }
        #expect(throws: VarintError.tooSmall) {
            var buf = buf
            _ = try Varint.getInt64(&buf)
        }
    }

    // INT64_CODE
    do {
        var buf = ByteBuffer()
        buf.writeInteger(Constants.INT64_CODE)

        // 64
        #expect(throws: VarintError.tooSmall) {
            var buf = buf
            _ = try Varint.getUInt64(&buf)
        }
        #expect(throws: VarintError.tooSmall) {
            var buf = buf
            _ = try Varint.getInt64(&buf)
        }
    }
}

@Test func randomTest() throws {
    var rng = SeededRandomNumberGenerator()

    // 8
    for _ in 0..<32 {
        let v: UInt8 = .random(in: UInt8.min...UInt8.max, using: &rng)
        var buf = ByteBuffer()
        Varint.putUInt8(v, &buf)
        let r = try Varint.getUInt8(&buf)
        #expect(v == r)
    }
    for _ in 0..<32 {
        let v: Int8 = .random(in: Int8.min...Int8.max, using: &rng)
        var buf = ByteBuffer()
        Varint.putInt8(v, &buf)
        let r = try Varint.getInt8(&buf)
        #expect(v == r)
    }

    // 16
    for _ in 0..<32 {
        let v: UInt16 = .random(in: UInt16.min...UInt16.max, using: &rng)
        var buf = ByteBuffer()
        Varint.putUInt16(v, &buf)
        let r = try Varint.getUInt16(&buf)
        #expect(v == r)
    }
    for _ in 0..<32 {
        let v: Int16 = .random(in: Int16.min...Int16.max, using: &rng)
        var buf = ByteBuffer()
        Varint.putInt16(v, &buf)
        let r = try Varint.getInt16(&buf)
        #expect(v == r)
    }

    // 32
    for _ in 0..<32 {
        let v: UInt32 = .random(in: UInt32.min...UInt32.max, using: &rng)
        var buf = ByteBuffer()
        Varint.putUInt32(v, &buf)
        let r = try Varint.getUInt32(&buf)
        #expect(v == r)
    }
    for _ in 0..<32 {
        let v: Int32 = .random(in: Int32.min...Int32.max, using: &rng)
        var buf = ByteBuffer()
        Varint.putInt32(v, &buf)
        let r = try Varint.getInt32(&buf)
        #expect(v == r)
    }

    // 64
    for _ in 0..<32 {
        let v: UInt64 = .random(in: UInt64.min...UInt64.max, using: &rng)
        var buf = ByteBuffer()
        Varint.putUInt64(v, &buf)
        let r = try Varint.getUInt64(&buf)
        #expect(v == r)
    }
    for _ in 0..<32 {
        let v: Int64 = .random(in: Int64.min...Int64.max, using: &rng)
        var buf = ByteBuffer()
        Varint.putInt64(v, &buf)
        let r = try Varint.getInt64(&buf)
        #expect(v == r)
    }
}
