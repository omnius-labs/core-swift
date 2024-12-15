import Foundation

public struct Timestamp64 {
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

struct Timestamp96 {
    var seconds: Int64
    var nanos: UInt32

    public init(seconds: Int64, nanos: UInt32) {
        self.seconds = seconds
        self.nanos = nanos
    }

    public init(date: Date) {
        self.seconds = Int64(date.timeIntervalSince1970)
        self.nanos = UInt32(
            date.timeIntervalSince1970.truncatingRemainder(dividingBy: 1) * 1_000_000_000)
    }

    public func toDate() -> Date {
        let interval = TimeInterval(seconds) + TimeInterval(nanos) / 1_000_000_000
        return Date(timeIntervalSince1970: interval)
    }
}
