import Foundation
import NIO
import RocketPack

public class OmniRemotingCaller<TError>
where TError: RocketMessage & CustomStringConvertible & Sendable {
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
        self.receiver = FramedReceiver(
            tcpClient, maxFrameLength: maxFrameLength, allocator: allocator)
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

    public func call<TParam, TResult>(_ param: TParam) async throws -> TResult
    where
        TParam: RocketMessage,
        TResult: RocketMessage
    {
        var sendingBytes = try OmniRemotingPacketMessage<TParam, TError>.complete(param).export()
        try await sender.send(&sendingBytes)

        var receivedBytes = try await receiver.receive()
        let result = try OmniRemotingPacketMessage<TResult, TError>.import(&receivedBytes)

        switch result {
        case .unknown: throw OmniRemotingError<TError>.protocolError(.unexpectedProtocol)
        case .continue(_): throw OmniRemotingError<TError>.protocolError(.unexpectedProtocol)
        case .complete(let receivedResult): return receivedResult
        case .error(let received_error_message):
            throw OmniRemotingError<TError>.applicationError(received_error_message)
        }
    }
}
