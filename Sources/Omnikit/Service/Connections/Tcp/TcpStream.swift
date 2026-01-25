import Dispatch
import Foundation
import NIO
import NIOFoundationCompat
import OmniusCoreBase
import Semaphore

public actor TcpStream: AsyncReadable, AsyncWritable, Sendable {
    private let channel: NIO.Channel
    private let receivedDataQueue: TcpUtils.AsyncQueue<TcpStreamReceivedData>

    init(channel: NIO.Channel) {
        self.channel = channel
        self.receivedDataQueue = TcpUtils.AsyncQueue()
    }

    public func close() async throws {
        try await self.channel.close().get()
    }

    public func read(length: Int) async throws -> ByteBuffer {
        if length <= 0 { return ByteBuffer.init() }

        while true {
            if self.receivedDataQueue.count() == 0 {
                self.channel.read()
            }

            switch try await self.receivedDataQueue.peek() {
            case .bytes(var bufferReader):
                _ = try await self.receivedDataQueue.dequeue()
                return bufferReader.buffer.readSlice(length: length) ?? ByteBuffer.init()
            case .inactive:
                return ByteBuffer.init()
            }
        }
    }

    public func write(buffer: ByteBuffer) async throws {
        try await self.channel.write(buffer).get()
    }

    public func flush() async throws {
        self.channel.flush()
    }

    nonisolated func enqueueReceive(_ data: TcpStreamReceivedData) {
        self.receivedDataQueue.enqueue(data)
    }
}

enum TcpStreamReceivedData: Sendable {
    case bytes(ByteBufferReader)
    case inactive
}

struct ByteBufferReader: Sendable {
    init(_ buffer: ByteBuffer) {
        self.buffer = buffer
    }

    public var buffer: ByteBuffer
}
