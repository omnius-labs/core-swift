import Foundation
import NIO

public enum FramedReceiverError: Error {
    case incompleteHeader
    case incompleteBody
    case frameTooLong
}

public final class FramedReceiver: Sendable {
    private let client: TcpClient
    private let maxFrameLength: Int
    private let allocator: ByteBufferAllocator

    private static let headerSize = 4

    public init(_ client: TcpClient, maxFrameLength: Int, allocator: ByteBufferAllocator) {
        self.client = client
        self.maxFrameLength = maxFrameLength
        self.allocator = allocator
    }

    public func receive() async throws -> ByteBuffer {
        var headerBuffer = self.allocator.buffer(capacity: Self.headerSize)
        while headerBuffer.readableBytes < Self.headerSize {
            let remain = Self.headerSize - headerBuffer.readableBytes
            var bytes = try await self.client.receive(length: remain)
            guard bytes.readableBytes > 0 else {
                throw FramedReceiverError.incompleteHeader
            }
            headerBuffer.writeBuffer(&bytes)
        }

        let bodyLength = Int(headerBuffer.readInteger(endianness: .little, as: UInt32.self)!)

        var bodyBuffer = self.allocator.buffer(capacity: Int(bodyLength))
        while bodyBuffer.readableBytes < bodyLength {
            let remain = bodyLength - bodyBuffer.readableBytes
            var bytes = try await self.client.receive(length: remain)
            guard bytes.readableBytes > 0 else {
                throw FramedReceiverError.incompleteBody
            }
            bodyBuffer.writeBuffer(&bytes)
        }

        return bodyBuffer
    }

    public func close() async throws {
        try await self.client.close()
    }
}
