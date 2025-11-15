import NIO
import RocketPack
import Testing

@testable import Omnikit

private struct CommunicationTestMessage: Equatable, Sendable {
    let value: Int32
}

extension CommunicationTestMessage: RocketPackStruct {
    static func pack(encoder: any RocketPack.RocketPackEncoder, value: CommunicationTestMessage) throws {
        try encoder.writeI32(value.value)
    }

    static func unpack(decoder: any RocketPack.RocketPackDecoder) throws -> CommunicationTestMessage {
        let value = try decoder.readI32()
        return Self(value: value)
    }
}

@Test
func communicationStreamTest() async throws {
    let allocator = ByteBufferAllocator()
    let maxFrameLength = 1_024 * 1_024
    let functionId: UInt32 = 1
    let (callerStream, listenerStream) = DuplexStream.createPair(allocator: allocator)
    defer { callerStream.close() }

    let listenerTask = Task { () throws -> UInt32 in
        defer { listenerStream.close() }

        let sender = FramedSender(listenerStream, allocator: allocator)
        let receiver = FramedReceiver(listenerStream, maxFrameLength: maxFrameLength, allocator: allocator)

        let helloBytes = try await receiver.receive()
        let hello = try OmniRemotingHelloMessage.import(helloBytes)

        #expect(hello.version == .v1)
        #expect(hello.functionId == functionId)

        let stream = OmniRemotingStream(sender: sender, receiver: receiver)
        let received: CommunicationTestMessage = try await stream.receive()
        #expect(received.value == 1)

        try await stream.send(CommunicationTestMessage(value: received.value + 1))

        return hello.functionId
    }

    let sender = FramedSender(callerStream, allocator: allocator)
    let receiver = FramedReceiver(callerStream, maxFrameLength: maxFrameLength, allocator: allocator)
    let stream = OmniRemotingStream(sender: sender, receiver: receiver)

    let hello = OmniRemotingHelloMessage(version: .v1, functionId: functionId)
    let helloBuffer = ByteBuffer(bytes: try hello.export())
    try await sender.send(helloBuffer)

    try await stream.send(CommunicationTestMessage(value: 1))
    let response: CommunicationTestMessage = try await stream.receive()
    #expect(response.value == 2)

    let listenedFunctionId = try await listenerTask.value
    #expect(listenedFunctionId == functionId)
}
