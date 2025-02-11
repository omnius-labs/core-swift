import Foundation
import NIO

public protocol RocketMessage {
    static func pack(_ bytes: inout ByteBuffer, value: Self, depth: UInt32) throws
    static func unpack(_ bytes: inout ByteBuffer, depth: UInt32) throws -> Self
}

extension RocketMessage {
    public static func `import`(_ bytes: inout ByteBuffer) throws -> Self {
        return try Self.unpack(&bytes, depth: 0)
    }

    public func export() throws -> ByteBuffer {
        var bytes = ByteBufferAllocator().buffer(capacity: 0)
        try Self.pack(&bytes, value: self, depth: 0)
        return bytes
    }
}
