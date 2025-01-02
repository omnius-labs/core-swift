import Dispatch
import NIO
import Semaphore

public final class TcpListener: @unchecked Sendable {
    private let eventLoopGroup: EventLoopGroup
    private let serverBootstrap: ServerBootstrap
    private let handler: TcpListenerChannelInboundHandler
    private let dispatchQueue = DispatchQueue(label: "TcpListener")

    private var bindChannel: Channel?
    private let acceptedTcpClientQueue = AsyncQueue<TcpClient>()

    public init() {
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)

        let handler = TcpListenerChannelInboundHandler(
            acceptedTcpClientQueue: self.acceptedTcpClientQueue, dispatchQueue: self.dispatchQueue)
        self.serverBootstrap = ServerBootstrap(group: self.eventLoopGroup)
            .serverChannelOption(.backlog, value: 3)
            .serverChannelOption(.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(.maxMessagesPerRead, value: 16)
            .childChannelOption(.recvAllocator, value: AdaptiveRecvByteBufferAllocator())
            .childChannelOption(ChannelOptions.autoRead, value: false)
            .childChannelInitializer { channel in
                channel.pipeline.addHandler(handler)
            }
        self.handler = handler
    }

    public func bind(host: String, port: Int) async throws {
        self.bindChannel = try await self.serverBootstrap.bind(host: host, port: port).get()
    }

    public func close() async throws {
        guard let channel = self.bindChannel else {
            throw TcpError.notConnected
        }
        try await channel.close().get()
    }

    public func accept() async throws -> TcpClient {
        return try await self.acceptedTcpClientQueue.dequeue()
    }
}

final class TcpListenerChannelInboundHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = ByteBuffer

    private let acceptedQueue: AsyncQueue<TcpClient>
    private let dispatchQueue: DispatchQueue
    private var tcpClientManager = TcpClientManager()

    init(acceptedTcpClientQueue: AsyncQueue<TcpClient>, dispatchQueue: DispatchQueue) {
        self.acceptedQueue = acceptedTcpClientQueue
        self.dispatchQueue = dispatchQueue
    }

    func channelActive(context: ChannelHandlerContext) {
        let tcpClient = self.tcpClientManager.get(context.channel)
        self.acceptedQueue.enqueue(tcpClient)
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
