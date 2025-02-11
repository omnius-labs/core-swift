import Foundation
import NIO
import RocketPack

public enum OmniRemotingListenResult<T, E>
where T: RocketMessage, E: RocketMessage & CustomStringConvertible & Sendable {
    case success(T)
    case failure(E)
}

public class OmniRemotingListener<TError>
where TError: RocketMessage & CustomStringConvertible & Sendable {
    private let tcpClient: TcpClient
    private let sender: FramedSender
    private let receiver: FramedReceiver

    public var functionId: UInt32 = 0

    public init(tcpClient: TcpClient, maxFrameLength: Int, allocator: ByteBufferAllocator) {
        self.tcpClient = tcpClient
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
        var bytes = try await self.receiver.receive()
        let helloMessage = try OmniRemotingHelloMessage.import(&bytes)

        if helloMessage.version == .v1 {
            self.functionId = helloMessage.functionId
        }

        throw OmniRemotingError<TError>.protocolError(.unexpectedProtocol)
    }

    public func listen<TParam, TResult>(
        callback: (TParam) async -> OmniRemotingListenResult<TResult, TError>
    ) async throws
    where
        TParam: RocketMessage,
        TResult: RocketMessage
    {
        var bytes = try await self.receiver.receive()
        let param = try OmniRemotingPacketMessage<TParam, TError>.import(&bytes)

        switch param {
        case .unknown: throw OmniRemotingError<TError>.protocolError(.unexpectedProtocol)
        case .continue(_): throw OmniRemotingError<TError>.protocolError(.unexpectedProtocol)
        case .complete(let param):
            let result = await callback(param)
            switch result {
            case .success(let result):
                let result = OmniRemotingPacketMessage<TResult, TError>.complete(result)
                var bytes = try result.export()
                try await self.sender.send(&bytes)
            case .failure(let error):
                let error = OmniRemotingPacketMessage<TResult, TError>.error(error)
                var bytes = try error.export()
                try await self.sender.send(&bytes)
            }
        case .error(let received_error_message):
            throw OmniRemotingError<TError>.applicationError(received_error_message)
        }
    }
}
