import NIO
import OmniusCoreBase

actor IncomingBytes {
    private let channel: OmniusCoreBase.Channel<ByteBuffer>
    private var current: ByteBuffer = ByteBuffer()

    init() {
        self.channel = OmniusCoreBase.Channel<ByteBuffer>.createUnbounded()
    }

    func tryWrite(_ data: ByteBuffer) async -> Bool {
        await channel.writer.tryWrite(data)
    }

    func complete() async {
        await channel.writer.complete()
    }

    func completeAndDrain() async {
        await channel.writer.complete()
        await drain()
    }

    func read(length: Int) async throws -> ByteBuffer {
        if length <= 0 {
            return ByteBuffer()
        }

        while true {
            if current.readableBytes > 0 {
                let readLength = min(current.readableBytes, length)
                guard let slice = current.readSlice(length: readLength) else {
                    continue
                }

                if current.readableBytes == 0 {
                    current = ByteBuffer()
                }

                return slice
            }

            if let next = await channel.reader.tryRead() {
                current = next
                continue
            }

            let canRead = try await channel.reader.waitToRead()
            if !canRead {
                return ByteBuffer()
            }
        }
    }

    private func drain() async {
        current = ByteBuffer()
        while await channel.reader.tryRead() != nil {}
    }
}
