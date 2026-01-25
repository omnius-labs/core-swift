import Foundation
import NIO

public protocol AsyncReadable {
    /// Reads up to `length` bytes from this source.
    /// - Returns: A `Data` value whose `count` is in 0...length. A nonzero count means bytes were read.
    ///   A zero count can mean end-of-stream (which may be temporary for some sources) or that `length` was 0.
    func read(length: Int) async throws -> ByteBuffer
}

public enum AsyncReadError: Error, Sendable {
    case endOfStream
}

extension AsyncReadable {
    public func readExactly(length: Int) async throws -> ByteBuffer {
        if length <= 0 { return ByteBuffer.init() }

        var remain = length
        var result: ByteBuffer? = nil

        while remain > 0 {
            var chunk = try await read(length: remain)
            if chunk.readableBytes == 0 {
                throw AsyncReadError.endOfStream
            }
            if result == nil {
                result = chunk
            } else {
                result!.writeBuffer(&chunk)
            }
            remain -= chunk.readableBytes
        }

        return result!
    }

    public func readFully(length: Int) async throws -> ByteBuffer {
        if length <= 0 { return ByteBuffer.init() }

        var remain = length
        var result: ByteBuffer? = nil

        while remain > 0 {
            var chunk = try await read(length: remain)
            if chunk.readableBytes == 0 {
                break
            }
            if result == nil {
                result = chunk
            } else {
                result!.writeBuffer(&chunk)
            }
            remain -= chunk.readableBytes
        }

        return result ?? ByteBuffer.init()
    }
}
