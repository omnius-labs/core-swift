import NIO
import OmniusCoreOmnikit
import Testing

@testable import OmniusCoreYamux

@Test(.timeLimit(.minutes(1)))
func yamuxConnectionMultiStreamRoundTrip() async throws {
    let (clientTransport, serverTransport) = DuplexStream.createPair()
    let allocator = ByteBufferAllocator()

    let client = try YamuxConnection(transport: clientTransport, mode: .client, allocator: allocator)
    let server = try YamuxConnection(transport: serverTransport, mode: .server, allocator: allocator)

    async let accept1 = server.acceptStream()
    async let accept2 = server.acceptStream()

    let clientStream1 = try await client.connectStream()
    let clientStream2 = try await client.connectStream()

    var payload1 = allocator.buffer(capacity: 3)
    payload1.writeBytes([1, 2, 3])
    var payload2 = allocator.buffer(capacity: 2)
    payload2.writeBytes([9, 8])

    // Send first to emit SYN frames before awaiting accept.
    try await clientStream1.write(buffer: payload1)
    try await clientStream2.write(buffer: payload2)

    guard let serverStream1 = await accept1, let serverStream2 = await accept2 else {
        #expect(Bool(false))
        return
    }

    let serverStreams: [UInt32: YamuxStream] = [
        serverStream1.id: serverStream1,
        serverStream2.id: serverStream2,
    ]

    guard let target1 = serverStreams[clientStream1.id],
        let target2 = serverStreams[clientStream2.id]
    else {
        #expect(Bool(false))
        return
    }

    let received1 = try await target1.readExactly(length: 3)
    let received2 = try await target2.readExactly(length: 2)

    #expect(received1.readableBytesView == [1, 2, 3])
    #expect(received2.readableBytesView == [9, 8])

    try await clientStream1.close()
    try await clientStream2.close()

    let end1 = try await target1.read(length: 1)
    let end2 = try await target2.read(length: 1)

    #expect(end1.readableBytes == 0)
    #expect(end2.readableBytes == 0)

    await client.close()
    await server.close()
}
