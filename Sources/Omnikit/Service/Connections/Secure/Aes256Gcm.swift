import Foundation
import CryptoKit
import NIO

enum SecureError: Error {
    case unsupportedAlgorithm(String)
    case invalidFormat(String)
    case handshakeFailed(String)
    case encryptionFailed
    case decryptionFailed
}

final class Aes256GcmEncoder {
    private let key: SymmetricKey
    private var nonce: [UInt8]
    private let allocator: ByteBufferAllocator

    init(key: [UInt8], nonce: [UInt8], allocator: ByteBufferAllocator) throws {
        guard key.count == 32 else { throw SecureError.invalidFormat("enc key") }
        guard nonce.count == 12 else { throw SecureError.invalidFormat("enc nonce") }
        self.key = SymmetricKey(data: key)
        self.nonce = nonce
        self.allocator = allocator
    }

    func encode(_ plaintext: ByteBuffer) throws -> ByteBuffer {
        let data = Data(plaintext.readableBytesView)
        guard let nonce = try? AES.GCM.Nonce(data: self.nonce) else {
            throw SecureError.invalidFormat("nonce")
        }
        let sealedBox: AES.GCM.SealedBox
        do {
            sealedBox = try AES.GCM.seal(data, using: self.key, nonce: nonce)
        } catch {
            throw SecureError.encryptionFailed
        }

        var out = allocator.buffer(capacity: sealedBox.ciphertext.count + sealedBox.tag.count)
        out.writeBytes(sealedBox.ciphertext)
        out.writeBytes(sealedBox.tag)

        SecureUtils.incrementBytes(&self.nonce)
        return out
    }
}

final class Aes256GcmDecoder {
    private let key: SymmetricKey
    private var nonce: [UInt8]
    private let allocator: ByteBufferAllocator
    private static let tagSize = 16

    init(key: [UInt8], nonce: [UInt8], allocator: ByteBufferAllocator) throws {
        guard key.count == 32 else { throw SecureError.invalidFormat("dec key") }
        guard nonce.count == 12 else { throw SecureError.invalidFormat("dec nonce") }
        self.key = SymmetricKey(data: key)
        self.nonce = nonce
        self.allocator = allocator
    }

    func decode(_ ciphertextWithTag: ByteBuffer) throws -> ByteBuffer {
        guard ciphertextWithTag.readableBytes >= Self.tagSize else {
            throw SecureError.invalidFormat("ciphertext length")
        }

        let data = Data(ciphertextWithTag.readableBytesView)
        let cipherPart = data.prefix(data.count - Self.tagSize)
        let tagPart = data.suffix(Self.tagSize)

        guard let nonce = try? AES.GCM.Nonce(data: self.nonce) else {
            throw SecureError.invalidFormat("nonce")
        }

        let sealedBox: AES.GCM.SealedBox
        do {
            sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: cipherPart, tag: tagPart)
        } catch {
            throw SecureError.invalidFormat("sealed box")
        }

        let plaintextData: Data
        do {
            plaintextData = try AES.GCM.open(sealedBox, using: self.key)
        } catch {
            throw SecureError.decryptionFailed
        }

        SecureUtils.incrementBytes(&self.nonce)

        var buffer = allocator.buffer(capacity: plaintextData.count)
        buffer.writeBytes(plaintextData)
        return buffer
    }
}
