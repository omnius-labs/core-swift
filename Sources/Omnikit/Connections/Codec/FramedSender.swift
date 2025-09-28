import Foundation
import NIO
import NIOFoundationCompat

public final class FramedSender: @unchecked Sendable {
    private let sender: any AsyncSend
    private let allocator: ByteBufferAllocator

    private static let headerSize = 4

    public init(_ sender: any AsyncSend, allocator: ByteBufferAllocator) {
        self.sender = sender
        self.allocator = allocator
    }

    public func send(_ buffer: inout ByteBuffer) async throws {
        let frameLength = buffer.readableBytes
        var header = self.allocator.buffer(capacity: Self.headerSize)
        header.writeInteger(UInt32(frameLength), endianness: .little)
        try await self.sender.send(&header)

        try await self.sender.send(&buffer)
    }
}
