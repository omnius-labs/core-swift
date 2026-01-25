import Foundation
import OmniusCoreRocketPack

enum AuthType: UInt32, Sendable {
    case none = 0
    case sign = 1
}

struct KeyExchangeAlgorithmType: OptionSet, Sendable {
    let rawValue: UInt32
    static let none = KeyExchangeAlgorithmType([])
    static let x25519 = KeyExchangeAlgorithmType(rawValue: 1 << 0)
}

struct KeyDerivationAlgorithmType: OptionSet, Sendable {
    let rawValue: UInt32
    static let none = KeyDerivationAlgorithmType([])
    static let hkdf = KeyDerivationAlgorithmType(rawValue: 1 << 1)
}

struct CipherAlgorithmType: OptionSet, Sendable {
    let rawValue: UInt32
    static let none = CipherAlgorithmType([])
    static let aes256Gcm = CipherAlgorithmType(rawValue: 1 << 0)
}

struct HashAlgorithmType: OptionSet, Sendable {
    let rawValue: UInt32
    static let none = HashAlgorithmType([])
    static let sha3_256 = HashAlgorithmType(rawValue: 1 << 0)
}

struct ProfileMessage: Equatable, Sendable {
    let sessionId: [UInt8]
    let authType: AuthType
    let keyExchangeAlgorithmType: KeyExchangeAlgorithmType
    let keyDerivationAlgorithmType: KeyDerivationAlgorithmType
    let cipherAlgorithmType: CipherAlgorithmType
    let hashAlgorithmType: HashAlgorithmType
}

extension ProfileMessage: RocketPackStruct {
    static func pack<E: RocketPackEncoder>(encoder: inout E, value: ProfileMessage) throws {
        try encoder.writeMap(6)

        try encoder.writeU64(0)
        try encoder.writeBytes(value.sessionId)

        try encoder.writeU64(1)
        try encoder.writeU32(value.authType.rawValue)

        try encoder.writeU64(2)
        try encoder.writeU32(value.keyExchangeAlgorithmType.rawValue)

        try encoder.writeU64(3)
        try encoder.writeU32(value.keyDerivationAlgorithmType.rawValue)

        try encoder.writeU64(4)
        try encoder.writeU32(value.cipherAlgorithmType.rawValue)

        try encoder.writeU64(5)
        try encoder.writeU32(value.hashAlgorithmType.rawValue)
    }

    static func unpack<D: RocketPackDecoder>(decoder: inout D) throws -> ProfileMessage {
        var sessionId: [UInt8]?
        var authType: AuthType?
        var keyExchangeAlgorithmType: KeyExchangeAlgorithmType?
        var keyDerivationAlgorithmType: KeyDerivationAlgorithmType?
        var cipherAlgorithmType: CipherAlgorithmType?
        var hashAlgorithmType: HashAlgorithmType?

        let count = try decoder.readMap()
        for _ in 0..<count {
            switch try decoder.readU64() {
            case 0:
                sessionId = try decoder.readBytes()
            case 1:
                guard let t = AuthType(rawValue: try decoder.readU32()) else {
                    throw RocketPackDecoderError.other("parse error")
                }
                authType = t
            case 2:
                keyExchangeAlgorithmType = KeyExchangeAlgorithmType(rawValue: try decoder.readU32())
            case 3:
                keyDerivationAlgorithmType = KeyDerivationAlgorithmType(rawValue: try decoder.readU32())
            case 4:
                cipherAlgorithmType = CipherAlgorithmType(rawValue: try decoder.readU32())
            case 5:
                hashAlgorithmType = HashAlgorithmType(rawValue: try decoder.readU32())
            default:
                try decoder.skipField()
            }
        }

        guard let sessionId else { throw RocketPackDecoderError.other("missing field: session_id") }
        guard let authType else { throw RocketPackDecoderError.other("missing field: auth_type") }
        guard let keyExchangeAlgorithmType else { throw RocketPackDecoderError.other("missing field: key_exchange_algorithm_type") }
        guard let keyDerivationAlgorithmType else { throw RocketPackDecoderError.other("missing field: key_derivation_algorithm_type") }
        guard let cipherAlgorithmType else { throw RocketPackDecoderError.other("missing field: cipher_algorithm_type") }
        guard let hashAlgorithmType else { throw RocketPackDecoderError.other("missing field: hash_algorithm_type") }

        return ProfileMessage(
            sessionId: sessionId,
            authType: authType,
            keyExchangeAlgorithmType: keyExchangeAlgorithmType,
            keyDerivationAlgorithmType: keyDerivationAlgorithmType,
            cipherAlgorithmType: cipherAlgorithmType,
            hashAlgorithmType: hashAlgorithmType
        )
    }
}
