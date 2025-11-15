import Foundation
import NIO

public protocol RocketPackStruct {
    static func pack(encoder: RocketPackEncoder, value: Self) throws
    static func unpack(decoder: RocketPackDecoder) throws -> Self
}

extension RocketPackStruct {
    public func pack(to encoder: RocketPackEncoder) throws {
        try Self.pack(encoder: encoder, value: self)
    }

    public static func `import`(_ bytes: [UInt8]) throws -> Self {
        let decoder = RocketPackBytesDecoder(bytes: bytes)
        return try Self.unpack(decoder: decoder)
    }

    public static func `import`(_ bytes: ByteBuffer) throws -> Self {
        let decoder = RocketPackBytesDecoder(bytes: Array(bytes.readableBytesView))
        return try Self.unpack(decoder: decoder)
    }

    public func export() throws -> [UInt8] {
        let encoder = RocketPackBytesEncoder()
        try Self.pack(encoder: encoder, value: self)
        return encoder.bytes
    }
}
