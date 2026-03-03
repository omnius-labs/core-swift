import Foundation
import NIO
import OmniusCoreBase
import OmniusCoreRocketPack

public actor OmniRemotingCaller {
    private let sender: FramedSender
    private let receiver: FramedReceiver

    public nonisolated let functionId: UInt32

    public static func create(
        stream: any AsyncReadable & AsyncWritable & Sendable, functionId: UInt32, maxFrameLength: Int, allocator: ByteBufferAllocator
    ) async throws -> Self {
        let caller = Self(stream: stream, functionId: functionId, maxFrameLength: maxFrameLength, allocator: allocator)
        try await caller.handshake()
        return caller
    }

    init(stream: any AsyncReadable & AsyncWritable & Sendable, functionId: UInt32, maxFrameLength: Int, allocator: ByteBufferAllocator) {
        self.functionId = functionId
        self.sender = FramedSender(stream, maxFrameLength: maxFrameLength, allocator: allocator)
        self.receiver = FramedReceiver(stream, maxFrameLength: maxFrameLength, allocator: allocator)
    }

    private func handshake() async throws {
        let helloMessage = OmniRemotingHelloMessage(version: .v1, functionId: self.functionId)
        let bytes = try helloMessage.export()
        try await self.sender.send(bytes)
    }

    public func call_stream() async throws -> OmniRemotingStream {
        return OmniRemotingStream(sender: self.sender, receiver: self.receiver)
    }
}
