import NIO

public protocol AsyncSend {
    func send(_ buffer: inout ByteBuffer) async throws
}
