public struct EmptyRocketMessage: RocketPackStruct {
    public init() {}

    public static func pack(encoder: RocketPackEncoder, value: EmptyRocketMessage) throws {
        _ = encoder
        _ = value
        // Nothing to serialize.
    }

    public static func unpack(decoder: RocketPackDecoder) throws -> EmptyRocketMessage {
        _ = decoder
        // Nothing to deserialize.
        return EmptyRocketMessage()
    }
}
