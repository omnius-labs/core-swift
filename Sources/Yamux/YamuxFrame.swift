import NIO
import OmniusCoreBase

enum FrameTag: UInt8 {
    case data = 0
    case windowUpdate = 1
    case ping = 2
    case goAway = 3
}

struct FrameFlags: OptionSet {
    let rawValue: UInt16

    init(rawValue: UInt16) {
        self.rawValue = rawValue
    }

    static let syn = FrameFlags(rawValue: 1 << 0)
    static let ack = FrameFlags(rawValue: 1 << 1)
    static let fin = FrameFlags(rawValue: 1 << 2)
    static let rst = FrameFlags(rawValue: 1 << 3)
}

enum GoAwayCode: UInt32 {
    case normal = 0
    case protocolError = 1
    case internalError = 2
}

struct FrameHeader {
    static let supportedVersion: UInt8 = 0

    let version: UInt8
    let tag: FrameTag
    let flags: FrameFlags
    let streamId: UInt32
    let length: UInt32

    init(tag: FrameTag, flags: FrameFlags, streamId: UInt32, length: UInt32) {
        self.version = Self.supportedVersion
        self.tag = tag
        self.flags = flags
        self.streamId = streamId
        self.length = length
    }

    func encode(into buffer: inout ByteBuffer) {
        buffer.writeInteger(self.version)
        buffer.writeInteger(self.tag.rawValue)
        buffer.writeInteger(self.flags.rawValue, endianness: .big)
        buffer.writeInteger(self.streamId, endianness: .big)
        buffer.writeInteger(self.length, endianness: .big)
    }

    static func decode(from buffer: ByteBuffer) throws -> FrameHeader {
        guard buffer.readableBytes >= YamuxConstants.headerSize else {
            throw YamuxError.invalidFormat("Invalid yamux header length.")
        }

        let base = buffer.readerIndex
        guard let version: UInt8 = buffer.getInteger(at: base) else {
            throw YamuxError.invalidFormat("Invalid yamux header length.")
        }

        if version != Self.supportedVersion {
            throw YamuxError.protocolError("Unsupported yamux version: \(version).")
        }

        guard let tagRaw: UInt8 = buffer.getInteger(at: base + 1) else {
            throw YamuxError.invalidFormat("Invalid yamux header length.")
        }
        guard let tag = FrameTag(rawValue: tagRaw) else {
            throw YamuxError.protocolError("Unknown yamux tag: \(tagRaw).")
        }

        guard let flagsRaw: UInt16 = buffer.getInteger(at: base + 2, endianness: .big, as: UInt16.self),
            let streamId: UInt32 = buffer.getInteger(at: base + 4, endianness: .big, as: UInt32.self),
            let length: UInt32 = buffer.getInteger(at: base + 8, endianness: .big, as: UInt32.self)
        else {
            throw YamuxError.invalidFormat("Invalid yamux header length.")
        }

        return FrameHeader(tag: tag, flags: FrameFlags(rawValue: flagsRaw), streamId: streamId, length: length)
    }
}

struct Frame {
    let header: FrameHeader
    let body: ByteBuffer

    init(header: FrameHeader, body: ByteBuffer) {
        self.header = header
        self.body = body
    }

    static func data(
        streamId: UInt32,
        body: ByteBuffer,
        flags: FrameFlags,
        allocator: ByteBufferAllocator = .init()
    ) throws -> Frame {
        var source = body
        let length = source.readableBytes
        if length > Int(UInt32.max) {
            throw YamuxError.frameTooLarge(length)
        }

        let header = FrameHeader(tag: .data, flags: flags, streamId: streamId, length: UInt32(length))
        if length == 0 {
            return Frame(header: header, body: allocator.buffer(capacity: 0))
        }

        var copied = allocator.buffer(capacity: length)
        copied.writeBuffer(&source)
        return Frame(header: header, body: copied)
    }

    static func windowUpdate(
        streamId: UInt32,
        credit: UInt32,
        flags: FrameFlags,
        allocator: ByteBufferAllocator = .init()
    ) -> Frame {
        let header = FrameHeader(tag: .windowUpdate, flags: flags, streamId: streamId, length: credit)
        return Frame(header: header, body: allocator.buffer(capacity: 0))
    }

    static func ping(
        nonce: UInt32,
        flags: FrameFlags,
        allocator: ByteBufferAllocator = .init()
    ) -> Frame {
        let header = FrameHeader(tag: .ping, flags: flags, streamId: 0, length: nonce)
        return Frame(header: header, body: allocator.buffer(capacity: 0))
    }

    static func goAway(code: GoAwayCode, allocator: ByteBufferAllocator = .init()) -> Frame {
        let header = FrameHeader(tag: .goAway, flags: [], streamId: 0, length: code.rawValue)
        return Frame(header: header, body: allocator.buffer(capacity: 0))
    }
}

enum FrameCodec {
    static func read(
        from reader: any AsyncReadable & Sendable,
        allocator: ByteBufferAllocator = .init()
    ) async throws -> Frame? {
        let headerBuffer = try await reader.readFully(length: YamuxConstants.headerSize)
        if headerBuffer.readableBytes == 0 {
            return nil
        }
        if headerBuffer.readableBytes < YamuxConstants.headerSize {
            throw YamuxError.invalidFormat("Invalid yamux header length.")
        }

        let header = try FrameHeader.decode(from: headerBuffer)
        if header.tag != .data {
            return Frame(header: header, body: allocator.buffer(capacity: 0))
        }

        if header.length > UInt32(YamuxConstants.maxFrameBodyLength) {
            throw YamuxError.frameTooLarge(Int(header.length))
        }

        if header.length == 0 {
            return Frame(header: header, body: allocator.buffer(capacity: 0))
        }

        guard let bodyLength = Int(exactly: header.length) else {
            throw YamuxError.frameTooLarge(Int.max)
        }

        do {
            let body = try await reader.readExactly(length: bodyLength)
            return Frame(header: header, body: body)
        } catch AsyncReadError.endOfStream {
            throw YamuxError.invalidFormat("Incomplete yamux frame body.")
        }
    }

    static func write(
        to writer: any AsyncWritable & Sendable,
        frame: Frame,
        allocator: ByteBufferAllocator = .init()
    ) async throws {
        var headerBuffer = allocator.buffer(capacity: YamuxConstants.headerSize)
        frame.header.encode(into: &headerBuffer)
        try await writer.write(buffer: headerBuffer)

        if frame.body.readableBytes > 0 {
            try await writer.write(buffer: frame.body)
        }

        try await writer.flush()
    }
}
