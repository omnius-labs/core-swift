import Base
import Foundation
import NIO
import Testing

@testable import RocketPack

private func compose(_ major: UInt8, _ info: UInt8) -> UInt8 {
    (major << 5) | (info & 0b0001_1111)
}

@Test func normalBoolTest() throws {
    let cases: [([UInt8], Bool)] = [
        ([compose(7, 20)], false),
        ([compose(7, 21)], true),
    ]

    for (bytes, value) in cases {
        let encoder = RocketPackBytesEncoder()
        try encoder.writeBool(value)
        #expect(encoder.bytes == bytes)

        let decoder = RocketPackBytesDecoder(bytes: bytes)
        let decoded = try decoder.readBool()
        #expect(decoded == value)
    }
}

@Test func normalU8Test() throws {
    let cases: [([UInt8], UInt8)] = [
        ([compose(0, 0)], 0),
        ([compose(0, 23)], 23),
        ([compose(0, 24), 24], 24),
        ([compose(0, 24), 255], .max),
    ]

    for (bytes, value) in cases {
        let encoder = RocketPackBytesEncoder()
        try encoder.writeU8(value)
        #expect(encoder.bytes == bytes)

        let decoder = RocketPackBytesDecoder(bytes: bytes)
        let decoded = try decoder.readU8()
        #expect(decoded == value)
    }
}

@Test func normalU16Test() throws {
    let cases: [([UInt8], UInt16)] = [
        ([compose(0, 0)], 0),
        ([compose(0, 23)], 23),
        ([compose(0, 24), 24], 24),
        ([compose(0, 24), 255], UInt16(UInt8.max)),
        ([compose(0, 25), 255, 255], .max),
    ]

    for (bytes, value) in cases {
        let encoder = RocketPackBytesEncoder()
        try encoder.writeU16(value)
        #expect(encoder.bytes == bytes)

        let decoder = RocketPackBytesDecoder(bytes: bytes)
        let decoded = try decoder.readU16()
        #expect(decoded == value)
    }
}

@Test func normalU32Test() throws {
    let cases: [([UInt8], UInt32)] = [
        ([compose(0, 0)], 0),
        ([compose(0, 23)], 23),
        ([compose(0, 24), 24], 24),
        ([compose(0, 24), 255], UInt32(UInt8.max)),
        ([compose(0, 25), 255, 255], UInt32(UInt16.max)),
        ([compose(0, 26), 255, 255, 255, 255], .max),
    ]

    for (bytes, value) in cases {
        let encoder = RocketPackBytesEncoder()
        try encoder.writeU32(value)
        #expect(encoder.bytes == bytes)

        let decoder = RocketPackBytesDecoder(bytes: bytes)
        let decoded = try decoder.readU32()
        #expect(decoded == value)
    }
}

@Test func normalU64Test() throws {
    let cases: [([UInt8], UInt64)] = [
        ([compose(0, 0)], 0),
        ([compose(0, 23)], 23),
        ([compose(0, 24), 24], 24),
        ([compose(0, 24), 255], UInt64(UInt8.max)),
        ([compose(0, 25), 255, 255], UInt64(UInt16.max)),
        ([compose(0, 26), 255, 255, 255, 255], UInt64(UInt32.max)),
        ([compose(0, 27), 255, 255, 255, 255, 255, 255, 255, 255], .max),
    ]

    for (bytes, value) in cases {
        let encoder = RocketPackBytesEncoder()
        try encoder.writeU64(value)
        #expect(encoder.bytes == bytes)

        let decoder = RocketPackBytesDecoder(bytes: bytes)
        let decoded = try decoder.readU64()
        #expect(decoded == value)
    }
}

@Test func normalI8Test() throws {
    let cases: [([UInt8], Int8)] = [
        ([compose(0, 0)], 0),
        ([compose(0, 23)], 23),
        ([compose(0, 24), 24], 24),
        ([compose(0, 24), 127], .max),
        ([compose(1, 0)], -1),
        ([compose(1, 23)], -24),
        ([compose(1, 24), 24], -25),
        ([compose(1, 24), 127], .min),
    ]

    for (bytes, value) in cases {
        let encoder = RocketPackBytesEncoder()
        try encoder.writeI8(value)
        #expect(encoder.bytes == bytes)

        let decoder = RocketPackBytesDecoder(bytes: bytes)
        let decoded = try decoder.readI8()
        #expect(decoded == value)
    }
}

@Test func normalI16Test() throws {
    let maxPositive: Int16 = .max
    let cases: [([UInt8], Int16)] = [
        ([compose(0, 0)], 0),
        ([compose(0, 23)], 23),
        ([compose(0, 24), 24], 24),
        ([compose(0, 24), 255], Int16(UInt8.max)),
        ([compose(0, 25), 127, 255], maxPositive),
        ([compose(1, 0)], -1),
        ([compose(1, 23)], -24),
        ([compose(1, 24), 24], -25),
        ([compose(1, 24), 255], -Int16(UInt8.max) - 1),
        ([compose(1, 25), 1, 0], -Int16(UInt8.max) - 2),
        ([compose(1, 25), 127, 255], .min),
    ]

    for (bytes, value) in cases {
        let encoder = RocketPackBytesEncoder()
        try encoder.writeI16(value)
        #expect(encoder.bytes == bytes)

        let decoder = RocketPackBytesDecoder(bytes: bytes)
        let decoded = try decoder.readI16()
        #expect(decoded == value)
    }
}

@Test func normalI32Test() throws {
    let cases: [([UInt8], Int32)] = [
        ([compose(0, 0)], 0),
        ([compose(0, 23)], 23),
        ([compose(0, 24), 24], 24),
        ([compose(0, 24), 255], Int32(UInt8.max)),
        ([compose(0, 25), 255, 255], Int32(UInt16.max)),
        ([compose(0, 26), 127, 255, 255, 255], .max),
        ([compose(1, 0)], -1),
        ([compose(1, 23)], -24),
        ([compose(1, 24), 24], -25),
        ([compose(1, 24), 255], -Int32(UInt8.max) - 1),
        ([compose(1, 25), 1, 0], -Int32(UInt8.max) - 2),
        ([compose(1, 25), 255, 255], -Int32(UInt16.max) - 1),
        ([compose(1, 26), 0, 1, 0, 0], -Int32(UInt16.max) - 2),
        ([compose(1, 26), 127, 255, 255, 255], .min),
    ]

    for (bytes, value) in cases {
        let encoder = RocketPackBytesEncoder()
        try encoder.writeI32(value)
        #expect(encoder.bytes == bytes)

        let decoder = RocketPackBytesDecoder(bytes: bytes)
        let decoded = try decoder.readI32()
        #expect(decoded == value)
    }
}

@Test func normalI64Test() throws {
    let cases: [([UInt8], Int64)] = [
        ([compose(0, 0)], 0),
        ([compose(0, 23)], 23),
        ([compose(0, 24), 24], 24),
        ([compose(0, 24), 255], Int64(UInt8.max)),
        ([compose(0, 25), 255, 255], Int64(UInt16.max)),
        ([compose(0, 26), 255, 255, 255, 255], Int64(UInt32.max)),
        ([compose(0, 27), 127, 255, 255, 255, 255, 255, 255, 255], .max),
        ([compose(1, 0)], -1),
        ([compose(1, 23)], -24),
        ([compose(1, 24), 24], -25),
        ([compose(1, 24), 255], -Int64(UInt8.max) - 1),
        ([compose(1, 25), 1, 0], -Int64(UInt8.max) - 2),
        ([compose(1, 25), 255, 255], -Int64(UInt16.max) - 1),
        ([compose(1, 26), 0, 1, 0, 0], -Int64(UInt16.max) - 2),
        ([compose(1, 26), 255, 255, 255, 255], -Int64(UInt32.max) - 1),
        ([compose(1, 27), 0, 0, 0, 1, 0, 0, 0, 0], -Int64(UInt32.max) - 2),
        ([compose(1, 27), 127, 255, 255, 255, 255, 255, 255, 255], .min),
    ]

    for (bytes, value) in cases {
        let encoder = RocketPackBytesEncoder()
        try encoder.writeI64(value)
        #expect(encoder.bytes == bytes)

        let decoder = RocketPackBytesDecoder(bytes: bytes)
        let decoded = try decoder.readI64()
        #expect(decoded == value)
    }
}

@Test func normalF32Test() throws {
    let cases: [([UInt8], Float)] = [
        ([compose(7, 26), 0, 0, 0, 0], 0.0)
    ]

    for (bytes, value) in cases {
        let encoder = RocketPackBytesEncoder()
        try encoder.writeF32(value)
        #expect(encoder.bytes == bytes)

        let decoder = RocketPackBytesDecoder(bytes: bytes)
        let decoded = try decoder.readF32()
        #expect(decoded == value)
    }
}

@Test func normalF64Test() throws {
    let cases: [([UInt8], Double)] = [
        ([compose(7, 27), 0, 0, 0, 0, 0, 0, 0, 0], 0.0)
    ]

    for (bytes, value) in cases {
        let encoder = RocketPackBytesEncoder()
        try encoder.writeF64(value)
        #expect(encoder.bytes == bytes)

        let decoder = RocketPackBytesDecoder(bytes: bytes)
        let decoded = try decoder.readF64()
        #expect(decoded == value)
    }
}

@Test func normalBytesTest() throws {
    let cases: [([UInt8], [UInt8])] = [
        ([compose(2, 0)], []),
        ([compose(2, 1), 0], [0]),
        (([compose(2, 23)] + Array(repeating: 0, count: 23)), Array(repeating: 0, count: 23)),
        (([compose(2, 24), 24] + Array(repeating: 0, count: 24)), Array(repeating: 0, count: 24)),
    ]

    for (bytes, value) in cases {
        let encoder = RocketPackBytesEncoder()
        try encoder.writeBytes(value)
        #expect(encoder.bytes == bytes)

        let decoder = RocketPackBytesDecoder(bytes: bytes)
        let decoded = try decoder.readBytes()
        #expect(decoded == value)
    }
}

@Test func normalStringTest() throws {
    let cases: [([UInt8], String)] = [
        ([compose(3, 0)], ""),
        ([compose(3, 6), 65, 65, 66, 66, 67, 67], "AABBCC"),
    ]

    for (bytes, value) in cases {
        let encoder = RocketPackBytesEncoder()
        try encoder.writeString(value)
        #expect(encoder.bytes == bytes)

        let decoder = RocketPackBytesDecoder(bytes: bytes)
        let decoded = try decoder.readString()
        #expect(decoded == value)
    }
}

@Test func normalArrayTest() throws {
    let cases: [([UInt8], Int)] = [
        ([compose(4, 1)], 1)
    ]

    for (bytes, value) in cases {
        let encoder = RocketPackBytesEncoder()
        try encoder.writeArray(value)
        #expect(encoder.bytes == bytes)

        let decoder = RocketPackBytesDecoder(bytes: bytes)
        let decoded = try decoder.readArray()
        #expect(decoded == UInt64(value))
    }
}

@Test func normalMapTest() throws {
    let cases: [([UInt8], Int)] = [
        ([compose(5, 1)], 1)
    ]

    for (bytes, value) in cases {
        let encoder = RocketPackBytesEncoder()
        try encoder.writeMap(value)
        #expect(encoder.bytes == bytes)

        let decoder = RocketPackBytesDecoder(bytes: bytes)
        let decoded = try decoder.readMap()
        #expect(decoded == UInt64(value))
    }
}

@Test func normalRawLenBytesTest() throws {
    let cases: [([UInt8], UInt64, UInt8)] = [
        ([compose(0, 0)], 0, 0),
        ([compose(0, 23)], 23, 23),
        ([compose(0, 24), 24], 24, 24),
        ([compose(0, 24), 255], UInt64(UInt8.max), 24),
        ([compose(0, 25), 255, 255], UInt64(UInt16.max), 25),
        ([compose(0, 26), 255, 255, 255, 255], UInt64(UInt32.max), 26),
        ([compose(0, 27), 255, 255, 255, 255, 255, 255, 255, 255], UInt64.max, 27),
    ]

    for (bytes, value, info) in cases {
        let encoder = RocketPackBytesEncoder()
        try encoder.writeRawLen(major: 0, length: value)
        #expect(encoder.bytes == bytes)

        let decoder = RocketPackBytesDecoder(bytes: Array(bytes.dropFirst()))
        let decoded = try decoder.readRawLen(info: info)
        #expect(decoded == value)
    }
}

@Test func normalDecoderTypeOfTest() throws {
    let cases: [([UInt8], FieldType)] = [
        ([compose(0, 0)], .u8),
        ([compose(0, 24)], .u8),
        ([compose(0, 25)], .u16),
        ([compose(0, 26)], .u32),
        ([compose(0, 27)], .u64),
        ([compose(1, 0)], .u8),
        ([compose(1, 24), 0], .i8),
        ([compose(1, 25), 0], .i16),
        ([compose(1, 26), 0], .i32),
        ([compose(1, 27), 0], .i64),
        ([compose(1, 24), 0x80], .i16),
        ([compose(1, 25), 0x80], .i32),
        ([compose(1, 26), 0x80], .i64),
        ([compose(2, 0)], .bytes),
        ([compose(3, 0)], .string),
        ([compose(4, 0)], .array),
        ([compose(5, 0)], .map),
        ([compose(7, 20)], .bool),
        ([compose(7, 21)], .bool),
        ([compose(7, 25)], .f16),
        ([compose(7, 26)], .f32),
        ([compose(7, 27)], .f64),
        ([compose(7, 31)], .unknown(major: 7, info: 31)),
    ]

    for (bytes, expectedType) in cases {
        let decoder = RocketPackBytesDecoder(bytes: bytes)
        let actual = try decoder.currentType()
        #expect(actual == expectedType)
    }
}

@Test func normalDecoderSkipFieldTest() throws {
    let p11: [UInt8] = [0xAA, 0xBB, 0xCC]
    let p13 = ["test_0", "test_1"]
    let p14: [(UInt32, String)] = [
        (0, "test_value_0"),
        (1, "test_value_1"),
        (2, "test_value_2"),
    ]

    let encoder = RocketPackBytesEncoder()
    try encoder.writeBool(true)
    try encoder.writeU8(1)
    try encoder.writeU16(2)
    try encoder.writeU32(3)
    try encoder.writeU64(4)
    try encoder.writeI8(5)
    try encoder.writeI16(6)
    try encoder.writeI32(7)
    try encoder.writeI64(8)
    try encoder.writeF32(9.5)
    try encoder.writeF64(10.5)
    try encoder.writeBytes(p11)
    try encoder.writeString("test")
    try encoder.writeArray(p13.count)
    for value in p13 {
        try encoder.writeString(value)
    }
    try encoder.writeMap(p14.count)
    for entry in p14 {
        try encoder.writeU32(entry.0)
        try encoder.writeString(entry.1)
    }

    let decoder = RocketPackBytesDecoder(bytes: encoder.bytes)
    for _ in 0...14 {
        try decoder.skipField()
    }

    #expect(decoder.remaining == 0)
}

@Test func truncatedNegativeNumberReportsEof() throws {
    let bytes = [compose(1, 24)]
    let decoder = RocketPackBytesDecoder(bytes: bytes)

    #expect(throws: RocketPackDecoderError.unexpectedEof) {
        _ = try decoder.currentType()
    }
}
