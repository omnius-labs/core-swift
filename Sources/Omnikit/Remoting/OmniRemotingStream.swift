import Foundation
import NIO
import RocketPack

public class OmniRemotingStream<TErrorMessage>
where TErrorMessage: RocketMessage & CustomStringConvertible & Sendable {
    private let sender: FramedSender
    private let receiver: FramedReceiver

    public init(sender: FramedSender, receiver: FramedReceiver) {
        self.sender = sender
        self.receiver = receiver
    }

    public func send<TMessage>(_ packet: OmniRemotingPacketMessage<TMessage, TErrorMessage>) async throws
    where
        TMessage: RocketMessage
    {
        var sendingBytes = try packet.export()
        try await sender.send(&sendingBytes)
    }

    public func receive<TMessage>() async throws -> OmniRemotingPacketMessage<TMessage, TErrorMessage>
    where
        TMessage: RocketMessage
    {
        var receivedBytes = try await self.receiver.receive()
        return try OmniRemotingPacketMessage<TMessage, TErrorMessage>.import(&receivedBytes)
    }
}
