import Foundation
import NIO

public protocol AsyncWritable {
    func write(buffer: ByteBuffer) async throws
    func flush() async throws
}

extension AsyncWritable {
    public func flush() async throws {}
}
