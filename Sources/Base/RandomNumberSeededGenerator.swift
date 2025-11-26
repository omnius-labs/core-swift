import GameplayKit

// ref. https://stackoverflow.com/questions/54821659/swift-4-2-seeding-a-random-number-generator

public class RandomNumberSeededGenerator: RandomNumberGenerator {
    let seed: UInt64
    private var generator: GKMersenneTwisterRandomSource

    public convenience init() {
        self.init(seed: 0)
    }

    public init(seed: UInt64) {
        self.seed = seed
        generator = GKMersenneTwisterRandomSource(seed: seed)
    }

    public func next() -> UInt64 {
        let next1 = UInt64(bitPattern: Int64(generator.nextInt()))
        let next2 = UInt64(bitPattern: Int64(generator.nextInt()))
        return (next1 << 32) | next2
    }

    func next<T>(upperBound: T) -> T where T: FixedWidthInteger, T: UnsignedInteger {
        return T(abs(generator.nextInt(upperBound: Int(upperBound))))
    }

    func next<T>() -> T where T: FixedWidthInteger, T: UnsignedInteger {
        return T(abs(generator.nextInt()))
    }
}
