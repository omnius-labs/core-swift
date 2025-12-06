import Base
import Foundation
import NIO

public enum OmniSecureStreamType {
    case connected
    case accepted
}

public actor OmniSecureStream: AsyncSend, AsyncReceive, @unchecked Sendable {
    private let receiver: FramedReceiver
    private let sender: FramedSender
    private let encoder: Aes256GcmEncoder
    private let decoder: Aes256GcmDecoder
    private let maxPlaintextLength: Int
    private let allocator: ByteBufferAllocator
    private let signValue: String?

    private var pendingPlaintext: ByteBuffer?

    public init(
        type: OmniSecureStreamType,
        stream: any AsyncSend & AsyncReceive,
        signer: OmniSigner? = nil,
        randomBytesProvider: any RandomBytesProvider = RandomBytesProviderImpl(),
        clock: any Clock = SystemClock(),
        allocator: ByteBufferAllocator = ByteBufferAllocator(),
        maxFrameLength: Int = 1024 * 64
    ) async throws {
        self.allocator = allocator
        self.maxPlaintextLength = maxFrameLength
        self.receiver = FramedReceiver(stream, maxFrameLength: maxFrameLength + 16, allocator: allocator)
        self.sender = FramedSender(stream, maxFrameLength: maxFrameLength + 16, allocator: allocator)

        let authenticator = Authenticator(
            type: type,
            receiver: self.receiver,
            sender: self.sender,
            signer: signer,
            randomBytesProvider: randomBytesProvider,
            clock: clock,
            allocator: allocator
        )

        let auth = try await authenticator.authenticate()
        self.encoder = try Aes256GcmEncoder(key: auth.encKey, nonce: auth.encNonce, allocator: allocator)
        self.decoder = try Aes256GcmDecoder(key: auth.decKey, nonce: auth.decNonce, allocator: allocator)
        self.signValue = auth.sign
    }

    public func send(_ buffer: ByteBuffer) async throws {
        var plain = buffer
        while plain.readableBytes > 0 {
            let size = min(self.maxPlaintextLength, plain.readableBytes)
            let chunk = plain.readSlice(length: size)!
            let encrypted = try self.encoder.encode(chunk)
            try await self.sender.send(encrypted)
        }
    }

    public func receive(length: Int) async throws -> ByteBuffer {
        guard length > 0 else { return self.allocator.buffer(capacity: 0) }

        var result = self.allocator.buffer(capacity: length)
        while result.readableBytes < length {
            if var pending = self.pendingPlaintext, pending.readableBytes > 0 {
                let take = min(length - result.readableBytes, pending.readableBytes)
                if let slice = pending.readSlice(length: take) {
                    var sliceCopy = slice
                    result.writeBuffer(&sliceCopy)
                }
                self.pendingPlaintext = pending.readableBytes > 0 ? pending : nil
                continue
            }

            let encrypted = try await self.receiver.receive()
            let plaintext = try self.decoder.decode(encrypted)
            if plaintext.readableBytes == 0 {
                return plaintext
            }
            self.pendingPlaintext = plaintext
        }

        return result
    }

    public var sign: String? {
        self.signValue
    }
}
