import Logging
import NIO
import OmniusCoreOmnikit
import Testing

@testable import OmniusCoreYamux

let logger = Logger(label: "logger") { label in
    var handler = StreamLogHandler.standardOutput(label: label)
    handler.logLevel = .debug
    return handler
}

@Test(.timeLimit(.minutes(1)))
func frameHeaderEncodeDecode() throws {
    let header = FrameHeader(
        tag: .data,
        flags: [.syn, .ack],
        streamId: 0x0102_0304,
        length: 0x0A0B_0C0D
    )

    let allocator = ByteBufferAllocator()
    var buffer = allocator.buffer(capacity: YamuxConstants.headerSize)
    header.encode(into: &buffer)

    let expected: [UInt8] = [
        0x00, 0x00,
        0x00, 0x03,
        0x01, 0x02, 0x03, 0x04,
        0x0A, 0x0B, 0x0C, 0x0D,
    ]
    #expect(expected.elementsEqual(buffer.readableBytesView))

    let decoded = try FrameHeader.decode(from: buffer)
    #expect(decoded.tag == header.tag)
    #expect(decoded.flags == header.flags)
    #expect(decoded.streamId == header.streamId)
    #expect(decoded.length == header.length)
}

@Test(.timeLimit(.minutes(1)))
func frameCodecRoundTripData() async throws {
    let (sender, receiver) = DuplexStream.createPair()
    let allocator = ByteBufferAllocator()

    var body = allocator.buffer(capacity: 4)
    body.writeBytes([1, 2, 3, 4])

    let frame = try Frame.data(streamId: 7, body: body, flags: [.syn], allocator: allocator)

    async let writeTask: Void = FrameCodec.write(to: sender, frame: frame, allocator: allocator)
    let readFrame = try await FrameCodec.read(from: receiver, allocator: allocator)
    try await writeTask

    #expect(readFrame != nil)
    guard let readFrame else { return }

    #expect(readFrame.header.tag == .data)
    #expect(readFrame.header.streamId == 7)
    #expect(readFrame.header.flags == [.syn])

    var received = readFrame.body
    let bytes = received.readBytes(length: received.readableBytes) ?? []
    #expect(bytes == [1, 2, 3, 4])
}

@Test(.timeLimit(.minutes(1)))
func frameCodecRoundTripPing() async throws {
    let (sender, receiver) = DuplexStream.createPair()
    let allocator = ByteBufferAllocator()

    let frame = Frame.ping(nonce: 0xA1B2_C3D4, flags: [.ack])

    async let writeTask: Void = FrameCodec.write(to: sender, frame: frame, allocator: allocator)
    let readFrame = try await FrameCodec.read(from: receiver, allocator: allocator)
    try await writeTask

    #expect(readFrame != nil)
    guard let readFrame else { return }

    #expect(readFrame.header.tag == .ping)
    #expect(readFrame.header.flags == [.ack])
    #expect(readFrame.header.length == 0xA1B2_C3D4)
    #expect(readFrame.body.readableBytes == 0)
}
