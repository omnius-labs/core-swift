import NIO

public protocol AsyncReceive {
    func receive(length: Int) async throws -> ByteBuffer
}
