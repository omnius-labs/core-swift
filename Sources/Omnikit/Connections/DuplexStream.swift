import Dispatch
import NIO

public final class DuplexStream: AsyncSend, AsyncReceive, @unchecked Sendable {
    private let inbound: AsyncQueue<ByteBuffer>
    private let outbound: AsyncQueue<ByteBuffer>
    private let allocator: ByteBufferAllocator
    private let stateQueue = DispatchQueue(label: "DuplexStream.state")

    private var pendingBuffer: ByteBuffer?
    private var closed = false

    public static func create(allocator: ByteBufferAllocator = ByteBufferAllocator()) -> (DuplexStream, DuplexStream) {
        let x = AsyncQueue<ByteBuffer>()
        let y = AsyncQueue<ByteBuffer>()

        let first = DuplexStream(inbound: x, outbound: y, allocator: allocator)
        let second = DuplexStream(inbound: y, outbound: x, allocator: allocator)
        return (first, second)
    }

    init(inbound: AsyncQueue<ByteBuffer>, outbound: AsyncQueue<ByteBuffer>, allocator: ByteBufferAllocator) {
        self.inbound = inbound
        self.outbound = outbound
        self.allocator = allocator
    }

    public func send(_ buffer: inout ByteBuffer) async throws {
        if self.isClosed {
            return
        }

        let copy = buffer
        self.outbound.enqueue(copy)
    }

    public func receive(length: Int) async throws -> ByteBuffer {
        if length <= 0 {
            return self.allocator.buffer(capacity: 0)
        }

        var result = self.allocator.buffer(capacity: length)

        while result.readableBytes < length {
            if var pending = self.takeFromPending(maxLength: length - result.readableBytes) {
                result.writeBuffer(&pending)
                continue
            }

            var next = try await self.inbound.dequeue()
            if next.readableBytes == 0 {
                return next
            }

            let remaining = length - result.readableBytes
            if next.readableBytes > remaining {
                var chunk = next.readSlice(length: remaining)!
                result.writeBuffer(&chunk)
                self.storePending(next)
                break
            } else {
                result.writeBuffer(&next)
            }
        }

        return result
    }

    public func close() {
        self.stateQueue.sync {
            self.closed = true
            self.pendingBuffer = nil
        }

        let empty = self.allocator.buffer(capacity: 0)
        self.outbound.enqueue(empty)
    }

    private var isClosed: Bool {
        return self.stateQueue.sync {
            self.closed
        }
    }

    private func takeFromPending(maxLength: Int) -> ByteBuffer? {
        return self.stateQueue.sync {
            guard var pending = self.pendingBuffer else {
                return nil
            }

            let length = min(maxLength, pending.readableBytes)
            guard length > 0, let slice = pending.readSlice(length: length) else {
                return nil
            }

            if pending.readableBytes == 0 {
                self.pendingBuffer = nil
            } else {
                self.pendingBuffer = pending
            }

            return slice
        }
    }

    private func storePending(_ buffer: ByteBuffer) {
        self.stateQueue.sync {
            guard buffer.readableBytes > 0 else {
                self.pendingBuffer = nil
                return
            }

            if self.pendingBuffer == nil {
                self.pendingBuffer = buffer
            } else {
                let existing = self.pendingBuffer!
                var newBuffer = self.allocator.buffer(capacity: existing.readableBytes + buffer.readableBytes)
                var existingCopy = existing
                var bufferCopy = buffer
                newBuffer.writeBuffer(&existingCopy)
                newBuffer.writeBuffer(&bufferCopy)
                self.pendingBuffer = newBuffer
            }
        }
    }
}
