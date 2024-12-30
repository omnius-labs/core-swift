import Foundation
import NIO
import Semaphore
import Socket
import Testing

@testable import Omnikit

@Test(.disabled()) func framedSendReceiveTest() async throws {
    let allocator = ByteBufferAllocator()

    let port = UInt16.random(in: 8080 ..< .max)
    let address = IPv4SocketAddress(address: .any, port: port)
    let listener = try await Socket(IPv4Protocol.tcp, bind: address)
    try await listener.listen()

    let serverTask = Task {
        let server = try await listener.accept()

        print("Server: accepted")

        let sender = FramedSender(socket: server, allocator: allocator)

        var message = allocator.buffer(string: "Hello, World!")
        try await sender.send(&message)
    }

    let clientTask = Task {
        let client = try await Socket(IPv4Protocol.tcp)

        // MEMO: なぜかここでエラーが発生する。公式のテストコードも同じようにエラーを無視している。
        // https://github.com/PureSwift/Socket/blob/253aef83213691b705dfeec8e20bfd7a72219fec/Tests/SocketTests/SocketTests.swift#L96
        do {
            try await client.connect(to: address)
        } catch Errno.socketIsConnected {}

        print("Client: connected")

        let receiver = FramedReceiver(socket: client, maxFrameLength: 1024, allocator: allocator)

        var message = try await receiver.receive()
        let string = message.readString(length: message.readableBytes)
        #expect(string == "Hello, World!")
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
