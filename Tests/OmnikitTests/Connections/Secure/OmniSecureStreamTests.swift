import Foundation
import NIO
import Semaphore
import Testing

@testable import Omnikit

@Test
func omniSecureStreamCommunicationTest() async throws {
    let allocator = ByteBufferAllocator()
    let (clientStream, serverStream) = DuplexStream.createPair(allocator: allocator)

    let maxSecureStreamFrameLength = 1024
    async let client = OmniSecureStream(
        type: .connected,
        stream: clientStream,
        allocator: allocator,
        maxFrameLength: maxSecureStreamFrameLength,
    )
    async let server = OmniSecureStream(
        type: .accepted,
        stream: serverStream,
        allocator: allocator,
        maxFrameLength: maxSecureStreamFrameLength,
    )

    let (secureClient, secureServer) = try await (client, server)

    let maxFrameLength = 1024 * 1024 * 32
    let sender = FramedSender(secureClient, maxFrameLength: maxFrameLength, allocator: allocator)
    let receiver = FramedReceiver(secureServer, maxFrameLength: maxFrameLength, allocator: allocator)

    let cases = [1, 2, 3, 10, 100, 1_000, 1_024 * 1_024]
    for size in cases {
        let bytes = (0..<size).map { _ in UInt8.random(in: UInt8.min...UInt8.max) }
        var message = allocator.buffer(capacity: size)
        message.writeBytes(bytes)

        try await sender.send(message)
        let received = try await receiver.receive()

        #expect(received.readableBytes == size)
        #expect(received.readableBytesView.elementsEqual(bytes))
    }
}
