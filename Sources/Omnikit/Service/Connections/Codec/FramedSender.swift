import Foundation
import NIO
import OmniusCoreBase

public protocol FramedSendable {
    func send(_ buffer: ByteBuffer) async throws
}

public enum FramedSenderError: Error, Sendable {
    case frameTooLong
}

public final class FramedSender: FramedSendable, Sendable {
    private let writer: any AsyncWritable & Sendable
    private let maxFrameLength: Int
    private let allocator: ByteBufferAllocator

    private static let headerSize = 4

    public init(_ writer: any AsyncWritable & Sendable, maxFrameLength: Int, allocator: ByteBufferAllocator) {
        self.writer = writer
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
        try await self.writer.write(buffer: header)
        try await self.writer.write(buffer: buffer)
        try await self.writer.flush()
    }
}
