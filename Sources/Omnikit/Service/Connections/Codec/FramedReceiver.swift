import Foundation
import NIO

public enum FramedReceiverError: Error {
    case incompleteHeader
    case incompleteBody
    case frameTooLong
}

public final class FramedReceiver: @unchecked Sendable {
    private let receiver: any AsyncReceive
    private let maxFrameLength: Int
    private let allocator: ByteBufferAllocator

    private static let headerSize = 4

    public init(_ receiver: any AsyncReceive, maxFrameLength: Int, allocator: ByteBufferAllocator) {
        self.receiver = receiver
        self.maxFrameLength = maxFrameLength
        self.allocator = allocator
    }

    public func receive() async throws -> ByteBuffer {
        var headerBuffer = self.allocator.buffer(capacity: Self.headerSize)
        while headerBuffer.readableBytes < Self.headerSize {
            let remain = Self.headerSize - headerBuffer.readableBytes
            var bytes = try await self.receiver.receive(length: remain)
            guard bytes.readableBytes > 0 else {
                throw FramedReceiverError.incompleteHeader
            }
            headerBuffer.writeBuffer(&bytes)
        }

        let bodyLength = Int(headerBuffer.readInteger(endianness: .little, as: UInt32.self)!)
        if bodyLength > self.maxFrameLength {
            throw FramedReceiverError.frameTooLong
        }

        var bodyBuffer = self.allocator.buffer(capacity: Int(bodyLength))
        while bodyBuffer.readableBytes < bodyLength {
            let remain = bodyLength - bodyBuffer.readableBytes
            var bytes = try await self.receiver.receive(length: remain)
            guard bytes.readableBytes > 0 else {
                throw FramedReceiverError.incompleteBody
            }
            bodyBuffer.writeBuffer(&bytes)
        }

        return bodyBuffer
    }
}
