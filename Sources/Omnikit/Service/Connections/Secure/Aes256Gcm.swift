import CryptoKit
import Foundation
import NIO

struct Aes256GcmEncoder: Sendable {
    private let key: SymmetricKey
    private var nonce: [UInt8]
    private let allocator: ByteBufferAllocator

    init(key: [UInt8], nonce: [UInt8], allocator: ByteBufferAllocator) throws {
        guard key.count == 32 else { throw OmniSecureStreamError.invalidFormat("enc key") }
        guard nonce.count == 12 else { throw OmniSecureStreamError.invalidFormat("enc nonce") }
        self.key = SymmetricKey(data: key)
        self.nonce = nonce
        self.allocator = allocator
    }

    mutating func encode(_ plaintext: ByteBuffer) throws -> ByteBuffer {
        let data = Data(plaintext.readableBytesView)
        guard let nonce = try? AES.GCM.Nonce(data: self.nonce) else {
            throw OmniSecureStreamError.invalidFormat("nonce")
        }

        let sealedBox: AES.GCM.SealedBox
        do {
            sealedBox = try AES.GCM.seal(data, using: self.key, nonce: nonce)
        } catch {
            throw OmniSecureStreamError.encryptionFailed
        }

        var out = self.allocator.buffer(capacity: sealedBox.ciphertext.count + sealedBox.tag.count)
        out.writeBytes(sealedBox.ciphertext)
        out.writeBytes(sealedBox.tag)

        SecureUtils.incrementBytes(&self.nonce)
        return out
    }
}

struct Aes256GcmDecoder: Sendable {
    private let key: SymmetricKey
    private var nonce: [UInt8]
    private let allocator: ByteBufferAllocator
    private static let tagSize = 16

    init(key: [UInt8], nonce: [UInt8], allocator: ByteBufferAllocator) throws {
        guard key.count == 32 else { throw OmniSecureStreamError.invalidFormat("dec key") }
        guard nonce.count == 12 else { throw OmniSecureStreamError.invalidFormat("dec nonce") }
        self.key = SymmetricKey(data: key)
        self.nonce = nonce
        self.allocator = allocator
    }

    mutating func decode(_ ciphertextWithTag: ByteBuffer) throws -> ByteBuffer {
        guard ciphertextWithTag.readableBytes >= Self.tagSize else {
            throw OmniSecureStreamError.invalidFormat("ciphertext length")
        }

        let data = Data(ciphertextWithTag.readableBytesView)
        let cipherPart = data.prefix(data.count - Self.tagSize)
        let tagPart = data.suffix(Self.tagSize)

        guard let nonce = try? AES.GCM.Nonce(data: self.nonce) else {
            throw OmniSecureStreamError.invalidFormat("nonce")
        }

        let sealedBox: AES.GCM.SealedBox
        do {
            sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: cipherPart, tag: tagPart)
        } catch {
            throw OmniSecureStreamError.invalidFormat("sealed box")
        }

        let plaintextData: Data
        do {
            plaintextData = try AES.GCM.open(sealedBox, using: self.key)
        } catch {
            throw OmniSecureStreamError.decryptionFailed
        }

        SecureUtils.incrementBytes(&self.nonce)

        var buffer = allocator.buffer(capacity: plaintextData.count)
        buffer.writeBytes(plaintextData)
        return buffer
    }
}
