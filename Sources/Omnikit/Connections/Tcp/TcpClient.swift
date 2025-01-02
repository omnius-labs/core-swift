import Dispatch
import NIO
import Semaphore

public actor TcpClient: AsyncSend, AsyncReceive, @unchecked Sendable {
    private let channel: Channel
    private let receivedDataQueue: AsyncQueue<TcpClientReceivedData>

    init(channel: Channel) {
        self.channel = channel
        self.receivedDataQueue = AsyncQueue()
    }

    public func close() async throws {
        try await self.channel.close().get()
    }

    public func send(_ buffer: inout ByteBuffer) async throws {
        try await self.channel.writeAndFlush(buffer).get()
    }

    public func receive(length: Int) async throws -> ByteBuffer {
        if length <= 0 {
            return ByteBuffer()
        }

        while true {
            if self.receivedDataQueue.count() == 0 {
                self.channel.read()
            }

            switch try await self.receivedDataQueue.peek() {
            case .bytes(let bufferWrapper):
                // discard
                if bufferWrapper.buffer.readableBytes == 0 {
                    let _ = try await self.receivedDataQueue.dequeue()
                    continue
                }

                let readLength = min(length, bufferWrapper.buffer.readableBytes)
                return bufferWrapper.buffer.readSlice(length: readLength)!
            case .inactive:
                return ByteBuffer()
            }
        }
    }

    nonisolated func enqueueReceive(_ data: TcpClientReceivedData) {
        self.receivedDataQueue.enqueue(data)
    }
}

enum TcpClientReceivedData: Sendable {
    case bytes(ByteBufferWrapper)
    case inactive
}

final class ByteBufferWrapper: @unchecked Sendable {
    var buffer: ByteBuffer

    init(_ buffer: ByteBuffer) {
        self.buffer = buffer
    }
}
