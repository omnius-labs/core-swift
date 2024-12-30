import Foundation
import NIO
import Socket

public enum FramedReceiverError: Error {
    case incompleteFrame
    case frameTooLong
}

public final class FramedReceiver: Sendable {
    private let socket: Socket
    private let maxFrameLength: Int
    private let allocator: ByteBufferAllocator

    private static let headerSize = 4

    public init(socket: Socket, maxFrameLength: Int, allocator: ByteBufferAllocator) {
        self.socket = socket
        self.maxFrameLength = maxFrameLength
        self.allocator = allocator
    }

    public func receive() async throws -> ByteBuffer {
        var headerBuffer = self.allocator.buffer(capacity: Self.headerSize)
        while headerBuffer.readableBytes < Self.headerSize {
            let remain = Self.headerSize - headerBuffer.readableBytes
            let bytesRead = try await self.socket.read(remain)
            guard bytesRead.count > 0 else {
                throw FramedReceiverError.incompleteFrame
            }
            headerBuffer.writeBytes(bytesRead)
        }

        let bodyLength = Int(headerBuffer.readInteger(endianness: .little, as: UInt32.self)!)

        var bodyBuffer = self.allocator.buffer(capacity: Int(bodyLength))
        while bodyBuffer.readableBytes < bodyLength {
            let remain = bodyLength - bodyBuffer.readableBytes
            let bytesRead = try await self.socket.read(remain)
            guard bytesRead.count > 0 else {
                throw FramedReceiverError.incompleteFrame
            }
            bodyBuffer.writeBytes(bytesRead)
        }

        return bodyBuffer
    }
}
