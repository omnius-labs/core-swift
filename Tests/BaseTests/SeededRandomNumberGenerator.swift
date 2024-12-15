import Testing

@testable import Base

@Test func simpleTest() async throws {
    var rng1 = SeededRandomNumberGenerator()
    var rng2 = SeededRandomNumberGenerator()

    for _ in 0..<32 {
        let v1: UInt8 = .random(in: UInt8.min...UInt8.max, using: &rng1)
        let v2: UInt8 = .random(in: UInt8.min...UInt8.max, using: &rng2)
        #expect(v1 == v2)
    }
}
