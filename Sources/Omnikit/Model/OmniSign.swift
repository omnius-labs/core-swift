import CryptoKit
import CryptoSwift
import Foundation
import RocketPack

public enum OmniSignType: String {
    case none = "none"
    case ed25519Sha3_256_Base64Url = "ed25519_sha3_256_base64url"
}

public struct OmniSigner {
    public let type: OmniSignType
    public let name: String
    public let key: Data

    public static func create(type: OmniSignType, name: String) throws -> OmniSigner {
        guard type == .ed25519Sha3_256_Base64Url else {
            throw SecureError.unsupportedAlgorithm("sign type")
        }

        let privateKey = Curve25519.Signing.PrivateKey()
        return OmniSigner(type: type, name: name, key: privateKey.rawRepresentation)
    }

    public func sign(_ message: [UInt8]) throws -> OmniCert {
        guard type == .ed25519Sha3_256_Base64Url else {
            throw SecureError.unsupportedAlgorithm("sign type")
        }

        let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: self.key)
        let signature = try privateKey.signature(for: Data(message))
        let publicKey = privateKey.publicKey.rawRepresentation
        let publicKeyDer = OmniCert.encodeEd25519PublicKeyDer(publicKey)

        return OmniCert(
            type: self.type,
            name: self.name,
            publicKey: publicKeyDer,
            value: signature
        )
    }

    public func descriptionString() throws -> String {
        guard type == .ed25519Sha3_256_Base64Url else { return "" }
        let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: self.key)
        let publicKeyDer = OmniCert.encodeEd25519PublicKeyDer(privateKey.publicKey.rawRepresentation)
        let hash = Digest.sha3(publicKeyDer.byteArray, variant: .sha256)
        return "\(self.name)@\(SecureUtils.base64Url(Data(hash)))"
    }
}

public struct OmniCert {
    public let type: OmniSignType
    public let name: String
    public let publicKey: Data
    public let value: Data

    public func verify(_ message: [UInt8]) throws {
        guard type == .ed25519Sha3_256_Base64Url else {
            throw SecureError.unsupportedAlgorithm("sign type")
        }

        let rawPublicKey = try OmniCert.decodeEd25519PublicKeyDer(self.publicKey)
        let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: rawPublicKey)
        if !publicKey.isValidSignature(self.value, for: Data(message)) {
            throw SecureError.handshakeFailed("invalid signature")
        }
    }

    public func descriptionString() throws -> String {
        guard type == .ed25519Sha3_256_Base64Url else { return "" }
        let hash = Digest.sha3(self.publicKey.byteArray, variant: .sha256)
        return "\(self.name)@\(SecureUtils.base64Url(Data(hash)))"
    }

    static func encodeEd25519PublicKeyDer(_ raw: Data) -> Data {
        // SEQUENCE {
        //   SEQUENCE { 1.3.101.112 }
        //   BIT STRING <public key>
        // }
        let prefix: [UInt8] = [0x30, 0x2a, 0x30, 0x05, 0x06, 0x03, 0x2b, 0x65, 0x70, 0x03, 0x21, 0x00]
        var der = Data(prefix)
        der.append(raw)
        return der
    }

    static func decodeEd25519PublicKeyDer(_ der: Data) throws -> Data {
        let expectedPrefix: [UInt8] = [0x30, 0x2a, 0x30, 0x05, 0x06, 0x03, 0x2b, 0x65, 0x70, 0x03, 0x21, 0x00]
        guard der.count == expectedPrefix.count + 32 else {
            throw SecureError.invalidFormat("public key der length")
        }
        guard der.prefix(expectedPrefix.count).elementsEqual(expectedPrefix) else {
            throw SecureError.invalidFormat("public key der prefix")
        }
        return der.suffix(32)
    }
}

extension OmniSigner: RocketPackStruct {
    public static func pack(encoder: RocketPackEncoder, value: OmniSigner) throws {
        try encoder.writeMap(3)

        try encoder.writeU64(0)
        try encoder.writeString(value.type.rawValue)

        try encoder.writeU64(1)
        try encoder.writeString(value.name)

        try encoder.writeU64(2)
        try encoder.writeBytes(Array(value.key))
    }

    public static func unpack(decoder: RocketPackDecoder) throws -> OmniSigner {
        var type: OmniSignType?
        var name: String?
        var key: Data?

        let count = try decoder.readMap()
        for _ in 0..<count {
            switch try decoder.readU64() {
            case 0:
                let raw = try decoder.readString()
                guard let parsed = OmniSignType(rawValue: raw) else { throw RocketPackDecoderError.other("parse error") }
                type = parsed
            case 1:
                name = try decoder.readString()
            case 2:
                key = Data(try decoder.readBytes())
            default:
                try decoder.skipField()
            }
        }

        guard let type else { throw RocketPackDecoderError.other("missing field: type") }
        guard let name else { throw RocketPackDecoderError.other("missing field: name") }
        guard let key else { throw RocketPackDecoderError.other("missing field: key") }

        return OmniSigner(type: type, name: name, key: key)
    }
}

extension OmniCert: RocketPackStruct {
    public static func pack(encoder: RocketPackEncoder, value: OmniCert) throws {
        try encoder.writeMap(4)

        try encoder.writeU64(0)
        try encoder.writeString(value.type.rawValue)

        try encoder.writeU64(1)
        try encoder.writeString(value.name)

        try encoder.writeU64(2)
        try encoder.writeBytes(Array(value.publicKey))

        try encoder.writeU64(3)
        try encoder.writeBytes(Array(value.value))
    }

    public static func unpack(decoder: RocketPackDecoder) throws -> OmniCert {
        var type: OmniSignType?
        var name: String?
        var publicKey: Data?
        var value: Data?

        let count = try decoder.readMap()
        for _ in 0..<count {
            switch try decoder.readU64() {
            case 0:
                let raw = try decoder.readString()
                guard let parsed = OmniSignType(rawValue: raw) else { throw RocketPackDecoderError.other("parse error") }
                type = parsed
            case 1:
                name = try decoder.readString()
            case 2:
                publicKey = Data(try decoder.readBytes())
            case 3:
                value = Data(try decoder.readBytes())
            default:
                try decoder.skipField()
            }
        }

        guard let type else { throw RocketPackDecoderError.other("missing field: type") }
        guard let name else { throw RocketPackDecoderError.other("missing field: name") }
        guard let publicKey else { throw RocketPackDecoderError.other("missing field: public_key") }
        guard let value else { throw RocketPackDecoderError.other("missing field: value") }

        return OmniCert(type: type, name: name, publicKey: publicKey, value: value)
    }
}
