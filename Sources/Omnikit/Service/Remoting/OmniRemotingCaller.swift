import Foundation
import NIO
import RocketPack

public actor OmniRemotingCaller {
    private let tcpStream: TcpStream
    private let sender: FramedSender
    private let receiver: FramedReceiver

    public nonisolated let functionId: UInt32

    public static func create(tcpStream: TcpStream, functionId: UInt32, maxFrameLength: Int, allocator: ByteBufferAllocator) async throws -> Self {
        let caller = Self(tcpStream: tcpStream, functionId: functionId, maxFrameLength: maxFrameLength, allocator: allocator)
        try await caller.handshake()
        return caller
    }

    init(tcpStream: TcpStream, functionId: UInt32, maxFrameLength: Int, allocator: ByteBufferAllocator) {
        self.tcpStream = tcpStream
        self.functionId = functionId
        self.sender = FramedSender(tcpStream, allocator: allocator)
        self.receiver = FramedReceiver(tcpStream, maxFrameLength: maxFrameLength, allocator: allocator)
    }

    private func handshake() async throws {
        let helloMessage = OmniRemotingHelloMessage(version: .v1, functionId: self.functionId)
        let bytes = ByteBuffer(bytes: try helloMessage.export())
        try await self.sender.send(bytes)
    }

    public func close() async throws {
        try await self.tcpStream.close()
    }

    public func call_stream() async throws -> OmniRemotingStream {
        return OmniRemotingStream(sender: self.sender, receiver: self.receiver)
    }
}
