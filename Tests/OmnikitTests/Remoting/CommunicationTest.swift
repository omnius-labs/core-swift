import NIO
import RocketPack
import Testing

@testable import Omnikit

private struct CommunicationTestMessage: RocketMessage, Equatable, Sendable {
    let value: Int32

    static func pack(_ bytes: inout ByteBuffer, value: Self, depth: UInt32) throws {
        RocketMessageWriter.putInt32(value.value, &bytes)
    }

    static func unpack(_ bytes: inout ByteBuffer, depth: UInt32) throws -> Self {
        let value = try RocketMessageReader.getInt32(&bytes)
        return Self(value: value)
    }
}

@Test
func communicationStreamTest() async throws {
    let allocator = ByteBufferAllocator()
    let maxFrameLength = 1_024 * 1_024
    let functionId: UInt32 = 1
    let (callerEndpoint, listenerEndpoint) = DuplexStream.create(allocator: allocator)
    defer { callerEndpoint.close() }

    let listenerTask = Task { () throws -> UInt32 in
        defer { listenerEndpoint.close() }

        let sender = FramedSender(listenerEndpoint, allocator: allocator)
        let receiver = FramedReceiver(listenerEndpoint, maxFrameLength: maxFrameLength, allocator: allocator)

        var helloBytes = try await receiver.receive()
        let hello = try OmniRemotingHelloMessage.import(&helloBytes)

        #expect(hello.version == .v1)
        #expect(hello.functionId == functionId)

        let stream = OmniRemotingStream(sender: sender, receiver: receiver)
        let received: CommunicationTestMessage = try await stream.receive()
        #expect(received.value == 1)

        try await stream.send(CommunicationTestMessage(value: received.value + 1))

        return hello.functionId
    }

    let sender = FramedSender(callerEndpoint, allocator: allocator)
    let receiver = FramedReceiver(callerEndpoint, maxFrameLength: maxFrameLength, allocator: allocator)
    let stream = OmniRemotingStream(sender: sender, receiver: receiver)

    let hello = OmniRemotingHelloMessage(version: .v1, functionId: functionId)
    var helloBuffer = try hello.export()
    try await sender.send(&helloBuffer)

    try await stream.send(CommunicationTestMessage(value: 1))
    let response: CommunicationTestMessage = try await stream.receive()
    #expect(response.value == 2)

    let listenedFunctionId = try await listenerTask.value
    #expect(listenedFunctionId == functionId)
}
