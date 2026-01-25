import Foundation
import NIO
import Semaphore
import Testing

@testable import OmniusCoreOmnikit

@Test
func framedSendReceiveDuplexTest() async throws {
    let allocator = ByteBufferAllocator()
    let (stream1, stream2) = DuplexStream.createPair()

    let senderA = FramedSender(stream1, maxFrameLength: 1024, allocator: allocator)
    let receiverB = FramedReceiver(stream2, maxFrameLength: 1024, allocator: allocator)

    let messageA = allocator.buffer(string: "Hello, World! 1")
    try await senderA.send(messageA)

    var receivedB = try await receiverB.receive()
    let textB = receivedB.readString(length: receivedB.readableBytes)
    #expect(textB == "Hello, World! 1")

    let senderB = FramedSender(stream2, maxFrameLength: 1024, allocator: allocator)
    let receiverA = FramedReceiver(stream1, maxFrameLength: 1024, allocator: allocator)

    let messageB = allocator.buffer(string: "Hello, World! 2")
    try await senderB.send(messageB)

    var receivedA = try await receiverA.receive()
    let textA = receivedA.readString(length: receivedA.readableBytes)
    #expect(textA == "Hello, World! 2")

    try await stream1.close()
    try await stream2.close()
}
