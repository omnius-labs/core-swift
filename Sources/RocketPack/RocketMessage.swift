import Foundation
import NIO

public protocol RocketMessage {
    static func pack(_ writer: inout RocketMessageWriter, value: Self, depth: UInt32) throws
    static func unpack(_ reader: inout RocketMessageReader, depth: UInt32) throws -> Self
}

extension RocketMessage {
    public static func `import`(bytes: inout ByteBuffer) throws -> Self {
        var reader = RocketMessageReader(&bytes)
        return try Self.unpack(&reader, depth: 0)
    }

    public func export() throws -> ByteBuffer {
        var bytes = ByteBufferAllocator().buffer(capacity: 0)
        var writer = RocketMessageWriter(&bytes)
        try Self.pack(&writer, value: self, depth: 0)
        return bytes
    }
}
