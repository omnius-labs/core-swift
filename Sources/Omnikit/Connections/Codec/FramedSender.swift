import Foundation
import NIO
import NIOFoundationCompat
import Socket

public final class FramedSender: Sendable {
    private let socket: Socket
    private let allocator: ByteBufferAllocator

    private static let headerSize = 4

    public init(socket: Socket, allocator: ByteBufferAllocator) {
        self.socket = socket
        self.allocator = allocator
    }

    public func send(_ buffer: inout ByteBuffer) async throws {
        let frameLength = buffer.readableBytes
        var header = self.allocator.buffer(capacity: Self.headerSize)
        header.writeInteger(UInt32(frameLength), endianness: .little)
        try await self.socket.write(Data(buffer: header))

        try await self.socket.write(Data(buffer: buffer))
    }
}
