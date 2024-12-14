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
    var rng = SystemRandomNumberGenerator()

    // 8
    for _ in 0..<32 {
        let v: UInt8 = .random(in: UInt8.min...UInt8.max, using: &rng)
        var buf = Data()
        Varint.putUInt8(v, &buf)
        let r = try Varint.getUInt8(&buf)
        #expect(v == r)
    }
}
