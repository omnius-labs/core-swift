public struct SeededRandomNumberGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

extension SeededRandomNumberGenerator {
    public mutating func next<T>(upperBound: T) -> T where T: FixedWidthInteger, T: UnsignedInteger {
        return T(next() % UInt64(upperBound))
    }

    public mutating func next<T>() -> T where T: FixedWidthInteger, T: UnsignedInteger {
        return T(truncatingIfNeeded: next())
    }

    public mutating func getBytes(size: Int) -> [UInt8] {
        return (0..<size).map { _ in UInt8.random(in: UInt8.min...UInt8.max) }
    }
}
