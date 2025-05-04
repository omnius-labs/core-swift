import Foundation
import NIO
import RocketPack
import Semaphore
import Testing

@testable import Omnikit

// @Test
@Test(.disabled())
func OmniRemotingCallerTest() async throws {
    let connector = TcpConnector()
    let client = try await connector.connect(host: "127.0.0.1", port: 50000)
    let allocator = ByteBufferAllocator()

    let caller = OmniRemotingCaller<OmniRemotingDefaultErrorMessage>(
        tcpClient: client, functionId: 1, maxFrameLength: 1024 * 1024, allocator: allocator)

    try await caller.handshake()

    let param = OmniRemotingTestMessage(text: "test")
    let result: OmniRemotingTestMessage = try await caller.call_unary(param)

    print(result.text)
}

// @Test
@Test(.disabled())
func OmniRemotingListenerTest() async throws {
    let allocator = ByteBufferAllocator()

    let listener = TcpListener()
    try await listener.bind(host: "0.0.0.0", port: 50000)

    while true {
        let server = try await listener.accept()
        print("Server: accepted")

        let listener = OmniRemotingListener<OmniRemotingDefaultErrorMessage>(
            tcpClient: server, maxFrameLength: 1024 * 1024, allocator: allocator)

        try await listener.handshake()

        switch listener.functionId {
        case 1:
            try await listener.listen_unary(callback: OmniRemotingListenerTestCallback)
            break
        default:
            break
        }
    }
}

func OmniRemotingListenerTestCallback(param: OmniRemotingTestMessage) async
    -> OmniRemotingListenResult<OmniRemotingTestMessage, OmniRemotingDefaultErrorMessage>
{
    return OmniRemotingListenResult.success(param)
}

struct OmniRemotingTestMessage: RocketMessage, Equatable {
    public let text: String

    public init(text: String) {
        self.text = text
    }

    public static func pack(
        _ bytes: inout ByteBuffer, value: OmniRemotingTestMessage, depth: UInt32
    )
        throws
    {
        RocketMessageWriter.putString(value.text, &bytes)
    }

    public static func unpack(_ bytes: inout ByteBuffer, depth: UInt32) throws
        -> OmniRemotingTestMessage
    {
        let text = try RocketMessageReader.getString(&bytes, 1024)
        return OmniRemotingTestMessage(text: text)
    }
}
