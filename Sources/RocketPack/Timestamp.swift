import Foundation

public struct Timestamp64: Sendable {
    var seconds: Int64

    public init(seconds: Int64) {
        self.seconds = seconds
    }

    public init(date: Date) {
        self.seconds = Int64(date.timeIntervalSince1970)
    }

    public func toDate() -> Date {
        return Date(timeIntervalSince1970: TimeInterval(seconds))
    }
}

extension Timestamp64: RocketPackStruct {
    public static func pack<E: RocketPackEncoder>(encoder: inout E, value: Timestamp64) throws {
        try encoder.writeI64(value.seconds)
    }

    public static func unpack<D: RocketPackDecoder>(decoder: inout D) throws -> Timestamp64 {
        Timestamp64(seconds: try decoder.readI64())
    }
}

public struct Timestamp96: Sendable {
    var seconds: Int64
    var nanos: UInt32

    public init(seconds: Int64, nanos: UInt32) {
        self.seconds = seconds
        self.nanos = nanos
    }

    public init(date: Date) {
        self.seconds = Int64(date.timeIntervalSince1970)
        self.nanos = UInt32(date.timeIntervalSince1970.truncatingRemainder(dividingBy: 1) * 1_000_000_000)
    }

    public func toDate() -> Date {
        let interval = TimeInterval(seconds) + TimeInterval(nanos) / 1_000_000_000
        return Date(timeIntervalSince1970: interval)
    }
}

extension Timestamp96: RocketPackStruct {
    public static func pack<E: RocketPackEncoder>(encoder: inout E, value: Timestamp96) throws {
        try encoder.writeMap(2)

        try encoder.writeU64(0)
        try encoder.writeI64(value.seconds)

        try encoder.writeU64(1)
        try encoder.writeU32(value.nanos)
    }

    public static func unpack<D: RocketPackDecoder>(decoder: inout D) throws -> Timestamp96 {
        var seconds: Int64?
        var nanos: UInt32?

        let count = try decoder.readMap()

        for _ in 0..<count {
            switch try decoder.readU64() {
            case 0:
                seconds = try decoder.readI64()
            case 1:
                nanos = try decoder.readU32()
            default:
                try decoder.skipField()
            }
        }

        return Timestamp96(
            seconds: seconds ?? 0,
            nanos: nanos ?? 0
        )
    }
}
