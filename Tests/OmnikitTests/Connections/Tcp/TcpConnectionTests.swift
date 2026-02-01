import Logging
import NIO
import Testing

@testable import OmniusCoreOmnikit

let logger = Logger(label: "logger") { label in
    var handler = StreamLogHandler.standardOutput(label: label)
    handler.logLevel = .debug
    return handler
}

@Test(.timeLimit(.minutes(1)))
func tcpConnectionRoundTrip() async throws {
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 8)
    defer { Task { try? await group.shutdownGracefully() } }

    let listener = TcpListener(backlog: 128, eventLoopGroup: group)
    try await listener.bind(host: "127.0.0.1", port: 0)
    let port = try await listener.port()

    async let accepted = try await listener.accept()

    let connector = TcpConnector(eventLoopGroup: group)
    let clientStream = try await connector.connect(host: "127.0.0.1", port: port)
    let serverStream = try await accepted

    let allocator = ByteBufferAllocator()

    var clientPayload = allocator.buffer(capacity: 4)
    clientPayload.writeBytes([1, 2, 3, 4])
    try await clientStream.write(buffer: clientPayload)
    try await clientStream.flush()

    let receivedServer = try await serverStream.readExactly(length: 4)
    #expect(receivedServer.readableBytesView == [1, 2, 3, 4])

    var serverPayload = allocator.buffer(capacity: 3)
    serverPayload.writeBytes([9, 8, 7])
    try await serverStream.write(buffer: serverPayload)
    try await serverStream.flush()

    let receivedClient = try await clientStream.readExactly(length: 3)
    #expect(receivedClient.readableBytesView == [9, 8, 7])

    try await clientStream.close()
    try await serverStream.close()
    try await listener.close()
}
