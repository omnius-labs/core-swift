public struct EmptyRocketMessage: Equatable, Sendable {
    public init() {}
}

extension EmptyRocketMessage: RocketPackStruct {
    public static func pack(encoder: any RocketPackEncoder, value: Self) throws {

    }

    public static func unpack(decoder: any RocketPackDecoder) throws -> Self {
        return Self()
    }
}
