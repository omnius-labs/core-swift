import Foundation
import NIO
import OmniusCoreBase

public enum OmniSecureStreamType: Sendable {
    case connected
    case accepted
}

public actor OmniSecureStream: AsyncReadable, AsyncWritable, Sendable {
    private let maxPlaintextLength: Int
    private let receiver: FramedReceiver
    private let sender: FramedSender
    private let allocator: ByteBufferAllocator

    private var encoder: Aes256GcmEncoder
    private var decoder: Aes256GcmDecoder
    private let signValue: String?

    private var pendingPlaintext: ByteBuffer?
    private var pendingPlaintextOffset: Int = 0

    public init(
        type: OmniSecureStreamType,
        stream: any AsyncReadable & AsyncWritable & Sendable,
        signer: OmniSigner? = nil,
        maxFrameLength: Int = 1024 * 64,
        randomBytesProvider: any RandomBytesProvider & Sendable = RandomBytesProviderImpl(),
        clock: any Clock & Sendable = SystemClock(),
        allocator: ByteBufferAllocator = .init()
    ) async throws {
        self.maxPlaintextLength = maxFrameLength
        self.receiver = FramedReceiver(stream, maxFrameLength: maxFrameLength + 16, allocator: allocator)
        self.sender = FramedSender(stream, maxFrameLength: maxFrameLength + 16, allocator: allocator)
        self.allocator = allocator

        let authenticator = Authenticator(
            type: type,
            receiver: self.receiver,
            sender: self.sender,
            signer: signer,
            randomBytesProvider: randomBytesProvider,
            clock: clock,
        )

        let auth = try await authenticator.authenticate()
        self.encoder = try Aes256GcmEncoder(key: auth.encKey, nonce: auth.encNonce, allocator: allocator)
        self.decoder = try Aes256GcmDecoder(key: auth.decKey, nonce: auth.decNonce, allocator: allocator)
        self.signValue = auth.sign
    }

    public var sign: String? {
        self.signValue
    }

    public func read(length: Int) async throws -> ByteBuffer {
        if length <= 0 { return self.allocator.buffer(capacity: 0) }

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

    public func write(buffer: ByteBuffer) async throws {
        var plain = buffer
        while plain.readableBytes > 0 {
            let size = min(self.maxPlaintextLength, plain.readableBytes)
            let chunk = plain.readSlice(length: size)!
            let encrypted = try self.encoder.encode(chunk)
            try await self.sender.send(encrypted)
        }
    }
}

public enum OmniSecureStreamError: Error, Sendable {
    case unsupportedAlgorithm(String)
    case invalidFormat(String)
    case handshakeFailed(String)
    case encryptionFailed
    case decryptionFailed
}
