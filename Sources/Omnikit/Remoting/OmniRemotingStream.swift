import Foundation
import NIO
import RocketPack

public actor OmniRemotingStream {
    private let sender: FramedSender
    private let receiver: FramedReceiver

    public init(sender: FramedSender, receiver: FramedReceiver) {
        self.sender = sender
        self.receiver = receiver
    }

    public func send<T>(_ message: T) async throws
    where
        T: RocketMessage
    {
        var sendingBytes = try message.export()
        try await sender.send(&sendingBytes)
    }

    public func receive<T>() async throws -> T
    where
        T: RocketMessage
    {
        var receivedBytes = try await self.receiver.receive()
        return try T.import(&receivedBytes)
    }
}
