import Dispatch
import NIO
import Semaphore

public actor TcpConnector: Sendable {
    private let clientBootstrap: ClientBootstrap
    private let handler: TcpStreamChannelInboundHandler

    private let tcpStreamManager = TcpStreamManager()

    public init(eventLoopGroup: EventLoopGroup) {
        let handler = TcpStreamChannelInboundHandler(tcpStreamManager: self.tcpStreamManager)
        self.clientBootstrap = ClientBootstrap(group: eventLoopGroup)
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

final class TcpStreamChannelInboundHandler: ChannelInboundHandler, Sendable {
    typealias InboundIn = ByteBuffer

    private let tcpStreamManager: TcpStreamManager

    init(tcpStreamManager: TcpStreamManager) {
        self.tcpStreamManager = tcpStreamManager
    }

    func channelActive(context: ChannelHandlerContext) {
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
