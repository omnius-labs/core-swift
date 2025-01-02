import Foundation
import NIO
import Semaphore
import Testing

@testable import Omnikit

// @Test
@Test(.disabled())
func framedSendReceiveTest() async throws {
    let allocator = ByteBufferAllocator()

    let port = Int.random(in: 10000..<60000)
    let listener = TcpListener()
    try await listener.bind(host: "127.0.0.1", port: port)

    let serverTask = Task {
        let server = try await listener.accept()
        print("Server: accepted")

        let sender = FramedSender(server, allocator: allocator)
        let receiver = FramedReceiver(server, maxFrameLength: 1024, allocator: allocator)

        var message1 = allocator.buffer(string: "Hello, World! 1")
        try await sender.send(&message1)
        print("Server: sent")

        var message2 = try await receiver.receive()
        print("Server: received")
        let string2 = message2.readString(length: message2.readableBytes)
        #expect(string2 == "Hello, World! 2")

        try await server.close()
    }

    let clientTask = Task {
        let connector = TcpConnector()

        let client = try await connector.connect(host: "127.0.0.1", port: port)
        print("Client: connected")

        let sender = FramedSender(client, allocator: allocator)
        let receiver = FramedReceiver(client, maxFrameLength: 1024, allocator: allocator)

        var message1 = try await receiver.receive()
        print("Client: received")
        let string1 = message1.readString(length: message1.readableBytes)
        #expect(string1 == "Hello, World! 1")

        var message2 = allocator.buffer(string: "Hello, World! 2")
        try await sender.send(&message2)
        print("Client: sent")

        try await client.close()
    }

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await serverTask.value
        }
        group.addTask {
            try await clientTask.value
        }
        try await group.waitForAll()
    }
}
