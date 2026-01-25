import Testing

@testable import OmniusCoreBase

@Test func simpleTest() throws {
    var rng1 = SeededRandomNumberGenerator(seed: 0)
    var rng2 = SeededRandomNumberGenerator(seed: 0)

    for _ in 0..<32 {
        let v1: UInt8 = .random(in: UInt8.min...UInt8.max, using: &rng1)
        let v2: UInt8 = .random(in: UInt8.min...UInt8.max, using: &rng2)
        #expect(v1 == v2)
    }
}
