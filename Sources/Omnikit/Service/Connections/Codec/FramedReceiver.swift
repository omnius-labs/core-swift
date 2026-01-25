import Foundation
import NIO
import OmniusCoreBase

public protocol FramedReceivable {
    func receive() async throws -> ByteBuffer
}

public enum FramedReceiverError: Error, Sendable {
    case incompleteHeader
    case incompleteBody
    case frameTooLong
}

public final class FramedReceiver: FramedReceivable, Sendable {
    private let reader: any AsyncReadable & Sendable
    private let maxFrameLength: Int
    private let allocator: ByteBufferAllocator

    private static let headerSize = 4

    public init(_ reader: any AsyncReadable & Sendable, maxFrameLength: Int, allocator: ByteBufferAllocator) {
        self.reader = reader
        self.maxFrameLength = maxFrameLength
        self.allocator = allocator
    }

    public func receive() async throws -> ByteBuffer {
        guard var header = try? await self.reader.readExactly(length: Self.headerSize) else {
            throw FramedReceiverError.incompleteHeader
        }

        guard let bodyLength = header.readInteger(endianness: .little, as: Int32.self).map(Int.init) else {
            throw FramedReceiverError.incompleteHeader
        }

        if bodyLength > self.maxFrameLength {
            throw FramedReceiverError.frameTooLong
        }

        do {
            return try await self.reader.readExactly(length: bodyLength)
        } catch {
            throw FramedReceiverError.incompleteBody
        }
    }
}
