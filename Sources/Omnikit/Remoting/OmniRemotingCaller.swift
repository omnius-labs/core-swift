import Foundation
import NIO
import RocketPack

public class OmniRemotingCaller<TErrorMessage>
where TErrorMessage: RocketMessage & CustomStringConvertible & Sendable {
    private let tcpClient: TcpClient
    private let sender: FramedSender
    private let receiver: FramedReceiver

    public let functionId: UInt32

    public init(
        tcpClient: TcpClient, functionId: UInt32, maxFrameLength: Int,
        allocator: ByteBufferAllocator
    ) {
        self.tcpClient = tcpClient
        self.functionId = functionId
        self.sender = FramedSender(tcpClient, allocator: allocator)
        self.receiver = FramedReceiver(tcpClient, maxFrameLength: maxFrameLength, allocator: allocator)
    }

    public func close() async throws {
        try await self.tcpClient.close()
        try await self.sender.close()
        try await self.receiver.close()
    }

    public func handshake() async throws {
        let helloMessage = OmniRemotingHelloMessage(version: .v1, functionId: self.functionId)
        var bytes = try helloMessage.export()
        try await self.sender.send(&bytes)
    }

    public func call_unary<TRequestMessage, TResponseMessage>(_ param: TRequestMessage) async throws -> TResponseMessage
    where
        TRequestMessage: RocketMessage,
        TResponseMessage: RocketMessage
    {
        var sendingBytes = try OmniRemotingPacketMessage<TRequestMessage, TErrorMessage>.complete(param).export()
        try await sender.send(&sendingBytes)

        var receivedBytes = try await receiver.receive()
        let result = try OmniRemotingPacketMessage<TResponseMessage, TErrorMessage>.import(&receivedBytes)

        switch result {
        case .unknown: throw OmniRemotingError<TErrorMessage>.protocolError(.unsupportedType)
        case .continue(_): throw OmniRemotingError<TErrorMessage>.protocolError(.unsupportedType)
        case .complete(let message): return message
        case .error(let error_message): throw OmniRemotingError<TErrorMessage>.applicationError(error_message)
        }
    }

    public func call_stream() async throws -> OmniRemotingStream<TErrorMessage> {
        return OmniRemotingStream<TErrorMessage>(sender: self.sender, receiver: self.receiver)
    }
}
