import Foundation
import NIO

public protocol AsyncReadable {
    /// Reads up to `length` bytes from this source.
    /// - Returns: A ByteBuffer whose `readableBytes` is in 0...length.
    ///   Returning 0 should mean end-of-stream (define this contract clearly).
    func read(length: Int) async throws -> ByteBuffer
}

public enum AsyncReadError: Error, Sendable {
    case endOfStream
}

extension AsyncReadable {
    public func readExactly(length: Int) async throws -> ByteBuffer {
        try await readInternal(length: length, throwOnEOF: true)
    }

    public func readFully(length: Int) async throws -> ByteBuffer {
        try await readInternal(length: length, throwOnEOF: false)
    }

    private func readInternal(length: Int, throwOnEOF: Bool) async throws -> ByteBuffer {
        if length <= 0 { return ByteBuffer.init() }

        var remain = length
        var result: ByteBuffer? = nil

        while remain > 0 {
            var chunk = try await self.read(length: remain)
            if throwOnEOF && chunk.readableBytes == 0 {
                throw AsyncReadError.endOfStream
            }
            let readableBytes = min(chunk.readableBytes, remain)
            if result == nil {
                result = chunk
            } else {
                result!.writeBuffer(&chunk)
            }
            remain -= readableBytes
        }

        return result!
    }
}
