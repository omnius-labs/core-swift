import Foundation
import NIO
import RocketPack

public enum OmniRemotingListenResult<T, E>
where T: RocketMessage, E: RocketMessage & CustomStringConvertible & Sendable {
    case success(T)
    case error(E)
}

public class OmniRemotingListener<TErrorMessage>
where TErrorMessage: RocketMessage & CustomStringConvertible & Sendable {
    private let tcpClient: TcpClient
    private let sender: FramedSender
    private let receiver: FramedReceiver

    public var functionId: UInt32 = 0

    public init(tcpClient: TcpClient, maxFrameLength: Int, allocator: ByteBufferAllocator) {
        self.tcpClient = tcpClient
        self.sender = FramedSender(tcpClient, allocator: allocator)
        self.receiver = FramedReceiver(tcpClient, maxFrameLength: maxFrameLength, allocator: allocator)
    }

    public func close() async throws {
        try await self.tcpClient.close()
        try await self.sender.close()
        try await self.receiver.close()
    }

    public func handshake() async throws {
        var bytes = try await self.receiver.receive()
        let helloMessage = try OmniRemotingHelloMessage.import(&bytes)

        if helloMessage.version == .v1 {
            self.functionId = helloMessage.functionId
        }

        throw OmniRemotingError<TErrorMessage>.protocolError(.unsupportedVersion)
    }

    public func listen_unary<TParamMessage, TSuccessMessage>(
        callback: (TParamMessage) async -> OmniRemotingListenResult<TSuccessMessage, TErrorMessage>
    ) async throws
    where
        TParamMessage: RocketMessage,
        TSuccessMessage: RocketMessage
    {
        var bytes = try await self.receiver.receive()
        let param = try OmniRemotingPacketMessage<TParamMessage, TErrorMessage>.import(&bytes)

        switch param {
        case .unknown: throw OmniRemotingError<TErrorMessage>.protocolError(.unsupportedType)
        case .continue(_): throw OmniRemotingError<TErrorMessage>.protocolError(.unsupportedType)
        case .complete(let param):
            switch await callback(param) {
            case .success(let message):
                let message = OmniRemotingPacketMessage<TSuccessMessage, TErrorMessage>.complete(message)
                var bytes = try message.export()
                try await self.sender.send(&bytes)
            case .error(let error_message):
                let error_message = OmniRemotingPacketMessage<TSuccessMessage, TErrorMessage>.error(error_message)
                var bytes = try error_message.export()
                try await self.sender.send(&bytes)
            }
        case .error(let received_error_message):
            throw OmniRemotingError<TErrorMessage>.applicationError(received_error_message)
        }
    }

    public func listen_stream() async throws -> OmniRemotingStream<TErrorMessage> {
        return OmniRemotingStream<TErrorMessage>(sender: self.sender, receiver: self.receiver)
    }
}
