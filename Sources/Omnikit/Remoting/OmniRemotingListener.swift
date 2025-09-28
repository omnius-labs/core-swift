import Foundation
import NIO
import RocketPack

public enum OmniRemotingListenResult<T, E>
where T: RocketMessage, E: RocketMessage & CustomStringConvertible & Sendable {
    case success(T)
    case error(E)
}

public class OmniRemotingListener {
    private let tcpStream: TcpStream
    private let sender: FramedSender
    private let receiver: FramedReceiver

    public var functionId: UInt32 = 0

    public static func create(tcpStream: TcpStream, maxFrameLength: Int, allocator: ByteBufferAllocator) async throws -> Self {
        let listener = Self(tcpStream: tcpStream, maxFrameLength: maxFrameLength, allocator: allocator)
        try await listener.handshake()
        return listener
    }

    required init(tcpStream: TcpStream, maxFrameLength: Int, allocator: ByteBufferAllocator) {
        self.tcpStream = tcpStream
        self.sender = FramedSender(tcpStream, allocator: allocator)
        self.receiver = FramedReceiver(tcpStream, maxFrameLength: maxFrameLength, allocator: allocator)
    }

    private func handshake() async throws {
        var bytes = try await self.receiver.receive()
        let helloMessage = try OmniRemotingHelloMessage.import(&bytes)

        if helloMessage.version == .v1 {
            self.functionId = helloMessage.functionId
            return
        }

        throw OmniRemotingError.unsupportedType
    }

    public func close() async throws {
        try await self.tcpStream.close()
    }

    public func listen_stream() async throws -> OmniRemotingStream {
        return OmniRemotingStream(sender: self.sender, receiver: self.receiver)
    }
}
