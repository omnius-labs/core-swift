import Dispatch
import NIO
import Semaphore

public final class TcpConnector: @unchecked Sendable {
    private let eventLoopGroup: EventLoopGroup
    private let clientBootstrap: ClientBootstrap
    private let handler: TcpClientChannelInboundHandler
    private let dispatchQueue = DispatchQueue(label: "TcpConnector")

    private var tcpClientManager = TcpClientManager()

    public init() {
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)

        let handler = TcpClientChannelInboundHandler(
            tcpClientManager: self.tcpClientManager, dispatchQueue: self.dispatchQueue)
        self.clientBootstrap = ClientBootstrap(group: self.eventLoopGroup)
            .channelOption(.socketOption(.so_reuseaddr), value: 1)
            .channelOption(.maxMessagesPerRead, value: 16)
            .channelOption(.recvAllocator, value: AdaptiveRecvByteBufferAllocator())
            .channelOption(ChannelOptions.autoRead, value: false)
            .channelInitializer { channel in
                channel.pipeline.addHandler(handler)
            }
        self.handler = handler
    }

    public func connect(host: String, port: Int) async throws -> TcpClient {
        let channel = try await self.clientBootstrap.connect(host: host, port: port).get()
        return self.tcpClientManager.get(channel)
    }
}

final class TcpClientChannelInboundHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = ByteBuffer

    private var tcpClientManager: TcpClientManager
    private let dispatchQueue: DispatchQueue

    init(tcpClientManager: TcpClientManager, dispatchQueue: DispatchQueue) {
        self.tcpClientManager = tcpClientManager
        self.dispatchQueue = dispatchQueue
    }

    func channelActive(context: ChannelHandlerContext) {
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let buffer = self.unwrapInboundIn(data)
        let tcpClient = self.tcpClientManager.get(context.channel)
        tcpClient.enqueueReceive(.bytes(ByteBufferWrapper(buffer)))
    }

    func channelInactive(context: ChannelHandlerContext) {
        let tcpClient = self.tcpClientManager.get(context.channel)
        tcpClient.enqueueReceive(.inactive)
    }
}
