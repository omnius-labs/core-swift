public struct EmptyRocketMessage: Equatable, Sendable {
    public init() {}
}

extension EmptyRocketMessage: RocketPackStruct {
    public static func pack<E: RocketPackEncoder>(encoder: inout E, value: Self) throws {

    }

    public static func unpack<D: RocketPackDecoder>(decoder: inout D) throws -> Self {
        return Self()
    }
}
