import Foundation
import NIO
import OmniusCoreBase

public protocol RocketPackStruct {
    static func pack<E: RocketPackEncoder>(encoder: inout E, value: Self) throws
    static func unpack<D: RocketPackDecoder>(decoder: inout D) throws -> Self
}

extension RocketPackStruct {
    public func pack<E: RocketPackEncoder>(to encoder: inout E) throws {
        try Self.pack(encoder: &encoder, value: self)
    }

    public static func `import`(_ data: Data) throws -> Self {
        let buffer = ByteBufferConverter.fromData(from: data)
        var decoder = RocketPackBytesDecoder(buffer: buffer)
        return try Self.unpack(decoder: &decoder)
    }

    public static func `import`(_ buffer: ByteBuffer) throws -> Self {
        var decoder = RocketPackBytesDecoder(buffer: buffer)
        return try Self.unpack(decoder: &decoder)
    }

    public func export(allocator: ByteBufferAllocator = .init()) throws -> ByteBuffer {
        var encoder = RocketPackBytesEncoder(allocator: allocator)
        try Self.pack(encoder: &encoder, value: self)
        return encoder.buffer
    }
}
