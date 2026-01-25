import Dispatch
import NIO
import Semaphore

public actor TcpListener: Sendable {
    private let serverBootstrap: ServerBootstrap
    private let handler: TcpListenerChannelInboundHandler

    private var bindChannel: Channel?
    private let acceptedTcpStreamQueue = TcpUtils.AsyncQueue<TcpStream>()

    public init(backlog: Int32, eventLoopGroup: EventLoopGroup) {
        let handler = TcpListenerChannelInboundHandler(acceptedTcpStreamQueue: self.acceptedTcpStreamQueue)
        self.serverBootstrap = ServerBootstrap(group: eventLoopGroup)
            .serverChannelOption(.backlog, value: backlog)
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

final class TcpListenerChannelInboundHandler: ChannelInboundHandler, Sendable {
    typealias InboundIn = ByteBuffer

    private let acceptedQueue: TcpUtils.AsyncQueue<TcpStream>
    private let tcpStreamManager = TcpStreamManager()

    init(acceptedTcpStreamQueue: TcpUtils.AsyncQueue<TcpStream>) {
        self.acceptedQueue = acceptedTcpStreamQueue
    }

    func channelActive(context: ChannelHandlerContext) {
        let tcpStream = self.tcpStreamManager.get(context.channel)
        self.acceptedQueue.enqueue(tcpStream)
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let buffer = self.unwrapInboundIn(data)
        let tcpStream = self.tcpStreamManager.get(context.channel)
        tcpStream.enqueueReceive(.bytes(ByteBufferReader(buffer)))
    }

    func channelInactive(context: ChannelHandlerContext) {
        let tcpStream = self.tcpStreamManager.get(context.channel)
        tcpStream.enqueueReceive(.inactive)
    }
}
