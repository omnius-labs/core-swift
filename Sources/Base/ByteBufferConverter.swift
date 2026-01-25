import Foundation
import NIOCore
import NIOFoundationCompat

public enum ByteBufferConverter {
    public static func toData(from buf: ByteBuffer) -> Data {
        buf.getData(at: buf.readerIndex, length: buf.readableBytes) ?? Data()
    }

    public static func fromData(from data: Data, allocator: ByteBufferAllocator = .init()) -> ByteBuffer {
        var buf = allocator.buffer(capacity: data.count)
        buf.writeBytes(data)
        return buf
    }
}
