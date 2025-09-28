import Foundation
import NIO
import Semaphore
import Testing

@testable import Omnikit

@Test
func framedSendReceiveDuplexTest() async throws {
    let allocator = ByteBufferAllocator()
    let (endpointA, endpointB) = DuplexStream.create(allocator: allocator)

    let senderA = FramedSender(endpointA, allocator: allocator)
    let receiverB = FramedReceiver(endpointB, maxFrameLength: 1024, allocator: allocator)

    var messageA = allocator.buffer(string: "Hello, World! 1")
    try await senderA.send(&messageA)

    var receivedB = try await receiverB.receive()
    let textB = receivedB.readString(length: receivedB.readableBytes)
    #expect(textB == "Hello, World! 1")

    let senderB = FramedSender(endpointB, allocator: allocator)
    let receiverA = FramedReceiver(endpointA, maxFrameLength: 1024, allocator: allocator)

    var messageB = allocator.buffer(string: "Hello, World! 2")
    try await senderB.send(&messageB)

    var receivedA = try await receiverA.receive()
    let textA = receivedA.readString(length: receivedA.readableBytes)
    #expect(textA == "Hello, World! 2")

    endpointA.close()
    endpointB.close()
}
