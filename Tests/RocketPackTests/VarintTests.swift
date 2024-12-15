import Base
import Foundation
import Testing

@testable import RocketPack

@Test func emptyDataGetTest() async throws {
    var data = Data()

    // 8
    #expect(throws: VarintError.endOfInput) {
        _ = try Varint.getUInt8(&data)
    }
    #expect(throws: VarintError.endOfInput) {
        _ = try Varint.getInt8(&data)
    }

    // 16
    #expect(throws: VarintError.endOfInput) {
        _ = try Varint.getUInt16(&data)
    }
    #expect(throws: VarintError.endOfInput) {
        _ = try Varint.getInt16(&data)
    }
}

@Test func randomTest() async throws {
    var rng = SeededRandomNumberGenerator()

    // 8
    for _ in 0..<32 {
        let v: UInt8 = .random(in: UInt8.min...UInt8.max, using: &rng)
        var buf = Data()
        Varint.putUInt8(v, &buf)
        let r = try Varint.getUInt8(&buf)
        #expect(v == r)
    }
    for _ in 0..<32 {
        let v: Int8 = .random(in: Int8.min...Int8.max, using: &rng)
        var buf = Data()
        Varint.putInt8(v, &buf)
        let r = try Varint.getInt8(&buf)
        #expect(v == r)
    }

    // 16
    for _ in 0..<32 {
        let v: UInt16 = .random(in: UInt16.min...UInt16.max, using: &rng)
        var buf = Data()
        Varint.putUInt16(v, &buf)
        let r = try Varint.getUInt16(&buf)
        #expect(v == r)
    }
    for _ in 0..<32 {
        let v: Int16 = .random(in: Int16.min...Int16.max, using: &rng)
        var buf = Data()
        Varint.putInt16(v, &buf)
        let r = try Varint.getInt16(&buf)
        #expect(v == r)
    }

    // 32
    for _ in 0..<32 {
        let v: UInt32 = .random(in: UInt32.min...UInt32.max, using: &rng)
        var buf = Data()
        Varint.putUInt32(v, &buf)
        let r = try Varint.getUInt32(&buf)
        #expect(v == r)
    }
    for _ in 0..<32 {
        let v: Int32 = .random(in: Int32.min...Int32.max, using: &rng)
        var buf = Data()
        Varint.putInt32(v, &buf)
        let r = try Varint.getInt32(&buf)
        #expect(v == r)
    }

    // 64
    for _ in 0..<32 {
        let v: UInt64 = .random(in: UInt64.min...UInt64.max, using: &rng)
        var buf = Data()
        Varint.putUInt64(v, &buf)
        let r = try Varint.getUInt64(&buf)
        #expect(v == r)
    }
    // for _ in 0..<32 {
    //     let v: Int64 = .random(in: Int64.min...Int64.max, using: &rng)
    //     var buf = Data()
    //     Varint.putInt64(v, &buf)
    //     let r = try Varint.getInt64(&buf)
    //     #expect(v == r)
    // }
}
