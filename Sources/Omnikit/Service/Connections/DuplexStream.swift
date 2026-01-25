import Foundation
import NIO
import OmniusCoreBase

public actor DuplexStream: AsyncReadable, AsyncWritable, Sendable {
    private let inbound: OmniusCoreBase.Channel<ByteBuffer>
    private let outbound: OmniusCoreBase.Channel<ByteBuffer>

    private var pendingData: ByteBuffer?
    private var closed = false

    public static func createPair() -> (DuplexStream, DuplexStream) {
        let options = BoundedChannelOptions(capacity: 1024, fullMode: .wait)
        let x = OmniusCoreBase.Channel<ByteBuffer>.createBounded(options)
        let y = OmniusCoreBase.Channel<ByteBuffer>.createBounded(options)

        let first = DuplexStream(inbound: x, outbound: y)
        let second = DuplexStream(inbound: y, outbound: x)
        return (first, second)
    }

    private init(inbound: OmniusCoreBase.Channel<ByteBuffer>, outbound: OmniusCoreBase.Channel<ByteBuffer>) {
        self.inbound = inbound
        self.outbound = outbound
    }

    public func read(length: Int) async throws -> ByteBuffer {
        if self.closed { return ByteBuffer.init() }
        if length <= 0 { return ByteBuffer.init() }

        if var pending = self.pendingData, pending.readableBytes > 0 {
            let take = min(length, pending.readableBytes)
            if let slice = pending.readSlice(length: take) {
                self.pendingData = pending.readableBytes > 0 ? pending : nil
                return slice
            }
            self.pendingData = nil
        }

        do {
            while true {
                var buffer = try await self.inbound.reader.read()
                if buffer.readableBytes == 0 { continue }
                if buffer.readableBytes <= length { return buffer }

                if let head = buffer.readSlice(length: length) {
                    self.pendingData = buffer.readableBytes > 0 ? buffer : nil
                    return head
                }
            }
        } catch ChannelClosedError.closed {
            return ByteBuffer.init()
        }
    }

    public func write(buffer: ByteBuffer) async throws {
        if self.closed || buffer.readableBytes == 0 { return }

        try await self.outbound.writer.write(buffer)
    }

    public func close() async throws {
        self.closed = true
        self.pendingData = nil
        await self.outbound.writer.complete()
    }
}
