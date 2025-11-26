import Dispatch
import NIO
import Semaphore

public final class TcpListener: @unchecked Sendable {
    private let eventLoopGroup: EventLoopGroup
    private let serverBootstrap: ServerBootstrap
    private let handler: TcpListenerChannelInboundHandler
    private let dispatchQueue = DispatchQueue(label: "TcpListener")

    private var bindChannel: Channel?
    private let acceptedTcpStreamQueue = AsyncQueue<TcpStream>()

    public init() {
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)

        let handler = TcpListenerChannelInboundHandler(
            acceptedTcpStreamQueue: self.acceptedTcpStreamQueue, dispatchQueue: self.dispatchQueue)
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

    public func accept() async throws -> TcpStream {
        return try await self.acceptedTcpStreamQueue.dequeue()
    }
}

final class TcpListenerChannelInboundHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = ByteBuffer

    private let acceptedQueue: AsyncQueue<TcpStream>
    private let dispatchQueue: DispatchQueue
    private var tcpStreamManager = TcpStreamManager()

    init(acceptedTcpStreamQueue: AsyncQueue<TcpStream>, dispatchQueue: DispatchQueue) {
        self.acceptedQueue = acceptedTcpStreamQueue
        self.dispatchQueue = dispatchQueue
    }

    func channelActive(context: ChannelHandlerContext) {
        let tcpStream = self.tcpStreamManager.get(context.channel)
        self.acceptedQueue.enqueue(tcpStream)
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let buffer = self.unwrapInboundIn(data)
        let tcpStream = self.tcpStreamManager.get(context.channel)
        tcpStream.enqueueReceive(.bytes(ByteBufferWrapper(buffer)))
    }

    func channelInactive(context: ChannelHandlerContext) {
        let tcpStream = self.tcpStreamManager.get(context.channel)
        tcpStream.enqueueReceive(.inactive)
    }
}
