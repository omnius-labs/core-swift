import CryptoKit
import Foundation
import RocketPack

public enum OmniAgreementAlgorithmType: String {
    case none = "none"
    case x25519 = "x25519"

    var bitPattern: UInt32 {
        switch self {
        case .none:
            return 0
        case .x25519:
            return 1
        }
    }
}

public struct OmniAgreement {
    public let algorithmType: OmniAgreementAlgorithmType
    public let secretKey: Data
    public let publicKey: Data
    public let createdTime: Date

    public static func create(_ algorithmType: OmniAgreementAlgorithmType, createdAt: Date) throws -> OmniAgreement {
        guard algorithmType == .x25519 else {
            throw SecureError.unsupportedAlgorithm("key exchange algorithm")
        }

        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        let publicKey = privateKey.publicKey.rawRepresentation

        return OmniAgreement(
            algorithmType: algorithmType,
            secretKey: privateKey.rawRepresentation,
            publicKey: publicKey,
            createdTime: createdAt
        )
    }

    public func genAgreementPublicKey() -> OmniAgreementPublicKey {
        OmniAgreementPublicKey(algorithmType: self.algorithmType, publicKey: self.publicKey, createdTime: self.createdTime)
    }

    public func genAgreementPrivateKey() -> OmniAgreementPrivateKey {
        OmniAgreementPrivateKey(algorithmType: self.algorithmType, secretKey: self.secretKey, createdTime: self.createdTime)
    }

    public static func genSecret(_ privateKey: OmniAgreementPrivateKey, _ publicKey: OmniAgreementPublicKey) throws -> [UInt8] {
        guard privateKey.algorithmType == .x25519, publicKey.algorithmType == .x25519 else {
            throw SecureError.unsupportedAlgorithm("key exchange algorithm")
        }

        let priv = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: privateKey.secretKey)
        let pub = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: publicKey.publicKey)
        let sharedSecret = try priv.sharedSecretFromKeyAgreement(with: pub)
        return sharedSecret.withUnsafeBytes { Array($0) }
    }
}

public struct OmniAgreementPublicKey {
    public let algorithmType: OmniAgreementAlgorithmType
    public let publicKey: Data
    public let createdTime: Date
}

public struct OmniAgreementPrivateKey {
    public let algorithmType: OmniAgreementAlgorithmType
    public let secretKey: Data
    public let createdTime: Date
}

extension OmniAgreement: RocketPackStruct {
    public static func pack(encoder: RocketPackEncoder, value: OmniAgreement) throws {
        try encoder.writeMap(4)

        try encoder.writeU64(0)
        try encoder.writeString(value.algorithmType.rawValue)

        try encoder.writeU64(1)
        try encoder.writeBytes(Array(value.secretKey))

        try encoder.writeU64(2)
        try encoder.writeBytes(Array(value.publicKey))

        try encoder.writeU64(3)
        try encoder.writeStruct(Timestamp64(date: value.createdTime))
    }

    public static func unpack(decoder: RocketPackDecoder) throws -> OmniAgreement {
        var algorithmType: OmniAgreementAlgorithmType?
        var secretKey: Data?
        var publicKey: Data?
        var createdTime: Date?

        let count = try decoder.readMap()

        for _ in 0..<count {
            switch try decoder.readU64() {
            case 0:
                let raw = try decoder.readString()
                guard let parsed = OmniAgreementAlgorithmType(rawValue: raw) else {
                    throw RocketPackDecoderError.other("parse error")
                }
                algorithmType = parsed
            case 1:
                secretKey = Data(try decoder.readBytes())
            case 2:
                publicKey = Data(try decoder.readBytes())
            case 3:
                createdTime = try decoder.readStruct(ofType: Timestamp64.self).toDate()
            default:
                try decoder.skipField()
            }
        }

        guard let algorithmType else { throw RocketPackDecoderError.other("missing field: algorithm_type") }
        guard let secretKey else { throw RocketPackDecoderError.other("missing field: secret_key") }
        guard let publicKey else { throw RocketPackDecoderError.other("missing field: public_key") }
        guard let createdTime else { throw RocketPackDecoderError.other("missing field: created_time") }

        return OmniAgreement(algorithmType: algorithmType, secretKey: secretKey, publicKey: publicKey, createdTime: createdTime)
    }
}

extension OmniAgreementPublicKey: RocketPackStruct {
    public static func pack(encoder: RocketPackEncoder, value: OmniAgreementPublicKey) throws {
        try encoder.writeMap(3)

        try encoder.writeU64(0)
        try encoder.writeString(value.algorithmType.rawValue)

        try encoder.writeU64(1)
        try encoder.writeBytes(Array(value.publicKey))

        try encoder.writeU64(2)
        try encoder.writeStruct(Timestamp64(date: value.createdTime))
    }

    public static func unpack(decoder: RocketPackDecoder) throws -> OmniAgreementPublicKey {
        var algorithmType: OmniAgreementAlgorithmType?
        var publicKey: Data?
        var createdTime: Date?

        let count = try decoder.readMap()

        for _ in 0..<count {
            switch try decoder.readU64() {
            case 0:
                let raw = try decoder.readString()
                guard let parsed = OmniAgreementAlgorithmType(rawValue: raw) else {
                    throw RocketPackDecoderError.other("parse error")
                }
                algorithmType = parsed
            case 1:
                publicKey = Data(try decoder.readBytes())
            case 2:
                createdTime = try decoder.readStruct(ofType: Timestamp64.self).toDate()
            default:
                try decoder.skipField()
            }
        }

        guard let algorithmType else { throw RocketPackDecoderError.other("missing field: algorithm_type") }
        guard let publicKey else { throw RocketPackDecoderError.other("missing field: public_key") }
        guard let createdTime else { throw RocketPackDecoderError.other("missing field: created_time") }

        return OmniAgreementPublicKey(algorithmType: algorithmType, publicKey: publicKey, createdTime: createdTime)
    }
}

extension OmniAgreementPrivateKey: RocketPackStruct {
    public static func pack(encoder: RocketPackEncoder, value: OmniAgreementPrivateKey) throws {
        try encoder.writeMap(3)

        try encoder.writeU64(0)
        try encoder.writeString(value.algorithmType.rawValue)

        try encoder.writeU64(1)
        try encoder.writeBytes(Array(value.secretKey))

        try encoder.writeU64(2)
        try encoder.writeStruct(Timestamp64(date: value.createdTime))
    }

    public static func unpack(decoder: RocketPackDecoder) throws -> OmniAgreementPrivateKey {
        var algorithmType: OmniAgreementAlgorithmType?
        var secretKey: Data?
        var createdTime: Date?

        let count = try decoder.readMap()

        for _ in 0..<count {
            switch try decoder.readU64() {
            case 0:
                let raw = try decoder.readString()
                guard let parsed = OmniAgreementAlgorithmType(rawValue: raw) else {
                    throw RocketPackDecoderError.other("parse error")
                }
                algorithmType = parsed
            case 1:
                secretKey = Data(try decoder.readBytes())
            case 2:
                createdTime = try decoder.readStruct(ofType: Timestamp64.self).toDate()
            default:
                try decoder.skipField()
            }
        }

        guard let algorithmType else { throw RocketPackDecoderError.other("missing field: algorithm_type") }
        guard let secretKey else { throw RocketPackDecoderError.other("missing field: secret_key") }
        guard let createdTime else { throw RocketPackDecoderError.other("missing field: created_time") }

        return OmniAgreementPrivateKey(algorithmType: algorithmType, secretKey: secretKey, createdTime: createdTime)
    }
}
