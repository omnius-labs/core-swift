import Dispatch
import Foundation
import NIO
import NIOFoundationCompat
import OmniusCoreBase

public actor TcpStream: AsyncReadable, AsyncWritable, Sendable {
    private let channel: NIO.Channel
    private let receivedDataQueue: TcpUtils.AsyncQueue<TcpStreamReceivedData>
    private var pendingData: ByteBuffer?
    private var isClosed = false

    init(channel: NIO.Channel) {
        self.channel = channel
        self.receivedDataQueue = TcpUtils.AsyncQueue()
    }

    public func close() async throws {
        try await self.channel.close().get()
    }

    public func read(length: Int) async throws -> ByteBuffer {
        if length <= 0 { return ByteBuffer.init() }

        if var pending = self.pendingData, pending.readableBytes > 0 {
            let take = min(length, pending.readableBytes)
            let slice = pending.readSlice(length: take)!
            self.pendingData = pending
            return slice
        }

        while true {
            if self.receivedDataQueue.count() == 0 {
                if self.isClosed { return ByteBuffer.init() }
                self.channel.read()
            }

            switch try await self.receivedDataQueue.dequeue() {
            case .bytes(var bufferReader):
                if bufferReader.buffer.readableBytes == 0 {
                    continue
                }
                if bufferReader.buffer.readableBytes <= length {
                    return bufferReader.buffer
                }
                let slice = bufferReader.buffer.readSlice(length: length)!
                self.pendingData = bufferReader.buffer
                return slice
            case .closing:
                self.isClosed = true
            }
        }
    }

    public func write(buffer: ByteBuffer) async throws {
        try await self.channel.writeAndFlush(buffer).get()
    }

    public func flush() async throws {
    }

    nonisolated func enqueueReceive(_ data: TcpStreamReceivedData) {
        self.receivedDataQueue.enqueue(data)
    }
}

enum TcpStreamReceivedData: Sendable {
    case bytes(ByteBufferReader)
    case closing
}

struct ByteBufferReader: Sendable {
    init(_ buffer: ByteBuffer) {
        self.buffer = buffer
    }

    public var buffer: ByteBuffer
}
