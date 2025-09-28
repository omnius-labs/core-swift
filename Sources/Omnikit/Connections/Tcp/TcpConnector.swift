import Dispatch
import NIO
import Semaphore

public final class TcpConnector: @unchecked Sendable {
    private let eventLoopGroup: EventLoopGroup
    private let clientBootstrap: ClientBootstrap
    private let handler: TcpStreamChannelInboundHandler
    private let dispatchQueue = DispatchQueue(label: "TcpConnector")

    private var tcpStreamManager = TcpStreamManager()

    public init() {
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)

        let handler = TcpStreamChannelInboundHandler(
            tcpStreamManager: self.tcpStreamManager, dispatchQueue: self.dispatchQueue)
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

    public func connect(host: String, port: Int) async throws -> TcpStream {
        let channel = try await self.clientBootstrap.connect(host: host, port: port).get()
        return self.tcpStreamManager.get(channel)
    }
}

final class TcpStreamChannelInboundHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = ByteBuffer

    private var tcpStreamManager: TcpStreamManager
    private let dispatchQueue: DispatchQueue

    init(tcpStreamManager: TcpStreamManager, dispatchQueue: DispatchQueue) {
        self.tcpStreamManager = tcpStreamManager
        self.dispatchQueue = dispatchQueue
    }

    func channelActive(context: ChannelHandlerContext) {
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
