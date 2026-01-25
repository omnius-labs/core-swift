import Foundation

public protocol Clock {
    func now() -> Date
}

public struct SystemClock: Clock, Sendable {
    public init() {}
    public func now() -> Date { Date() }
}
