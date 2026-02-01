import Foundation
import NIO
import OmniusCoreBase
import Testing

@testable import OmniusCoreOmnikit

@Test(.timeLimit(.minutes(1)))
func omniSecureStreamCommunicationTest() async throws {
    let allocator = ByteBufferAllocator()
    var rng = SeededRandomNumberGenerator(seed: 0)

    let (clientStream, serverStream) = DuplexStream.createPair()

    let maxSecureStreamFrameLength = 16 * 1024
    async let client = OmniSecureStream(
        type: .connected,
        stream: clientStream,
        maxFrameLength: maxSecureStreamFrameLength,
    )
    async let server = OmniSecureStream(
        type: .accepted,
        stream: serverStream,
        maxFrameLength: maxSecureStreamFrameLength,
    )

    let (secureClient, secureServer) = try await (client, server)

    let maxFrameLength = 1024 * 1024 * 32
    let sender = FramedSender(secureClient, maxFrameLength: maxFrameLength, allocator: allocator)
    let receiver = FramedReceiver(secureServer, maxFrameLength: maxFrameLength, allocator: allocator)

    let cases = [1, 2, 3, 10, 100, 1_000, 1_024 * 1_024]
    for size in cases {
        let sendingBytes = ByteBuffer.init(bytes: rng.getBytes(size: size))

        async let sendTask: Void = sender.send(sendingBytes)
        async let receivedTask: ByteBuffer = receiver.receive()

        try await sendTask
        let receivedBytes = try await receivedTask

        #expect(receivedBytes == sendingBytes)
    }
}
