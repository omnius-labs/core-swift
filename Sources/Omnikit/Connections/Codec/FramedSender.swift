import Foundation
import NIO
import NIOFoundationCompat

public final class FramedSender: Sendable {
    private let client: TcpClient
    private let allocator: ByteBufferAllocator

    private static let headerSize = 4

    public init(_ client: TcpClient, allocator: ByteBufferAllocator) {
        self.client = client
        self.allocator = allocator
    }

    public func send(_ buffer: inout ByteBuffer) async throws {
        let frameLength = buffer.readableBytes
        var header = self.allocator.buffer(capacity: Self.headerSize)
        header.writeInteger(UInt32(frameLength), endianness: .little)
        try await self.client.send(&header)

        try await self.client.send(&buffer)
    }

    public func close() async throws {
        try await self.client.close()
    }
}
