import NIO

public struct EmptyRocketMessage: Equatable, Sendable {
    public init() {}
}

extension EmptyRocketMessage: RocketMessage {
    public static func pack(_ bytes: inout ByteBuffer, value: EmptyRocketMessage, depth _: UInt32) throws {}

    public static func unpack(_ bytes: inout ByteBuffer, depth _: UInt32) throws -> EmptyRocketMessage {
        EmptyRocketMessage()
    }
}
