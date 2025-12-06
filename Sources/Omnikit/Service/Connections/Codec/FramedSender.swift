import Foundation
import NIO
import NIOFoundationCompat

public enum FramedSenderError: Error {
    case frameTooLong
}

public final class FramedSender: @unchecked Sendable {
    private let sender: any AsyncSend
    private let maxFrameLength: Int
    private let allocator: ByteBufferAllocator

    private static let headerSize = 4

    public init(_ sender: any AsyncSend, maxFrameLength: Int, allocator: ByteBufferAllocator) {
        self.sender = sender
        self.maxFrameLength = maxFrameLength
        self.allocator = allocator
    }

    public func send(_ buffer: ByteBuffer) async throws {
        let frameLength = buffer.readableBytes
        if frameLength > self.maxFrameLength {
            throw FramedReceiverError.frameTooLong
        }

        var header = self.allocator.buffer(capacity: Self.headerSize)
        header.writeInteger(UInt32(frameLength), endianness: .little)
        try await self.sender.send(header)

        try await self.sender.send(buffer)
    }
}
