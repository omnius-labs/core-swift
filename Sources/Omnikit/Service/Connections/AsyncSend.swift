import NIO

public protocol AsyncSend {
    func send(_ buffer: ByteBuffer) async throws
}
