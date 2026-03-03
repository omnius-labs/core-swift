import Foundation
import NIO
import OmniusCoreBase
import OmniusCoreRocketPack

public actor OmniRemotingListener {
    private let sender: FramedSender
    private let receiver: FramedReceiver

    public var functionId: UInt32 = 0

    public static func create(
        stream: any AsyncReadable & AsyncWritable & Sendable, functionId: UInt32, maxFrameLength: Int, allocator: ByteBufferAllocator
    ) async throws -> Self {
        let listener = Self(stream: stream, functionId: functionId, maxFrameLength: maxFrameLength, allocator: allocator)
        try await listener.handshake()
        return listener
    }

    init(stream: any AsyncReadable & AsyncWritable & Sendable, functionId: UInt32, maxFrameLength: Int, allocator: ByteBufferAllocator) {
        self.sender = FramedSender(stream, maxFrameLength: maxFrameLength, allocator: allocator)
        self.receiver = FramedReceiver(stream, maxFrameLength: maxFrameLength, allocator: allocator)
    }

    private func handshake() async throws {
        let bytes = try await self.receiver.receive()
        let helloMessage = try OmniRemotingHelloMessage.import(bytes)

        if helloMessage.version == .v1 {
            self.functionId = helloMessage.functionId
            return
        }

        throw OmniRemotingError.unsupportedType
    }

    public func listen_stream() async throws -> OmniRemotingStream {
        return OmniRemotingStream(sender: self.sender, receiver: self.receiver)
    }
}
