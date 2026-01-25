import CryptoSwift
import Foundation
import NIO
import OmniusCoreBase
import OmniusCoreRocketPack

struct AuthResult: Sendable {
    let sign: String?
    let cipherAlgorithmType: CipherAlgorithmType
    let encKey: [UInt8]
    let encNonce: [UInt8]
    let decKey: [UInt8]
    let decNonce: [UInt8]
}

struct Authenticator: Sendable {
    private let type: OmniSecureStreamType
    private let receiver: FramedReceiver
    private let sender: FramedSender
    private let signer: OmniSigner?
    private let randomBytesProvider: any RandomBytesProvider & Sendable
    private let clock: any Clock & Sendable

    init(
        type: OmniSecureStreamType,
        receiver: FramedReceiver,
        sender: FramedSender,
        signer: OmniSigner?,
        randomBytesProvider: any RandomBytesProvider & Sendable,
        clock: any Clock & Sendable,
    ) {
        self.type = type
        self.receiver = receiver
        self.sender = sender
        self.signer = signer
        self.randomBytesProvider = randomBytesProvider
        self.clock = clock
    }

    func authenticate() async throws -> AuthResult {
        let myProfile = ProfileMessage(
            sessionId: self.randomBytesProvider.getBytes(32),
            authType: self.signer == nil ? .none : .sign,
            keyExchangeAlgorithmType: .x25519,
            keyDerivationAlgorithmType: .hkdf,
            cipherAlgorithmType: .aes256Gcm,
            hashAlgorithmType: .sha3_256
        )

        try await sendProfile(myProfile)
        let otherProfile = try await receiveProfile()

        let keyExchange = KeyExchangeAlgorithmType(
            rawValue: myProfile.keyExchangeAlgorithmType.rawValue & otherProfile.keyExchangeAlgorithmType.rawValue)
        let keyDerivation = KeyDerivationAlgorithmType(
            rawValue: myProfile.keyDerivationAlgorithmType.rawValue & otherProfile.keyDerivationAlgorithmType.rawValue)
        let cipher = CipherAlgorithmType(rawValue: myProfile.cipherAlgorithmType.rawValue & otherProfile.cipherAlgorithmType.rawValue)
        let hash = HashAlgorithmType(rawValue: myProfile.hashAlgorithmType.rawValue & otherProfile.hashAlgorithmType.rawValue)

        guard keyExchange.contains(.x25519) else { throw OmniSecureStreamError.unsupportedAlgorithm("key exchange algorithm") }
        let (otherSign, secret) = try await performKeyExchange(
            myProfile: myProfile,
            otherProfile: otherProfile,
            keyExchangeAlgorithmType: keyExchange,
            hashAlgorithmType: hash
        )

        guard cipher.contains(.aes256Gcm) else { throw OmniSecureStreamError.unsupportedAlgorithm("cipher algorithm") }
        let authResult = try deriveKeys(
            keyDerivationAlgorithmType: keyDerivation,
            hashAlgorithmType: hash,
            cipherAlgorithmType: cipher,
            myProfile: myProfile,
            otherProfile: otherProfile,
            secret: secret
        )

        return AuthResult(
            sign: otherSign,
            cipherAlgorithmType: cipher,
            encKey: authResult.encKey,
            encNonce: authResult.encNonce,
            decKey: authResult.decKey,
            decNonce: authResult.decNonce
        )
    }

    private func sendProfile(_ profile: ProfileMessage) async throws {
        let bytes = try profile.export()
        try await self.sender.send(bytes)
    }

    private func receiveProfile() async throws -> ProfileMessage {
        let bytes = try await self.receiver.receive()
        return try ProfileMessage.import(bytes)
    }

    private func performKeyExchange(
        myProfile: ProfileMessage,
        otherProfile: ProfileMessage,
        keyExchangeAlgorithmType: KeyExchangeAlgorithmType,
        hashAlgorithmType: HashAlgorithmType
    ) async throws -> (String?, [UInt8]) {
        guard keyExchangeAlgorithmType.contains(.x25519) else {
            throw OmniSecureStreamError.unsupportedAlgorithm("key exchange algorithm")
        }

        let now = self.clock.now()
        let myAgreement = try OmniAgreement.create(.x25519, createdAt: now)

        let myPublicKey = myAgreement.genAgreementPublicKey()
        let myPubBytes = try myPublicKey.export()
        try await self.sender.send(myPubBytes)

        let otherPubBuffer = try await self.receiver.receive()
        let otherPub = try OmniAgreementPublicKey.import(otherPubBuffer)

        if let signer = self.signer {
            let myHash = try genHash(profile: myProfile, agreementPublicKey: myPublicKey, hashAlgorithmType: hashAlgorithmType)
            let myCert = try signer.sign(myHash)
            try await self.sender.send(try myCert.export())
        }

        var otherSign: String?
        if otherProfile.authType == .sign {
            let certBuffer = try await self.receiver.receive()
            let otherCert = try OmniCert.import(certBuffer)
            let otherHash = try genHash(profile: otherProfile, agreementPublicKey: otherPub, hashAlgorithmType: hashAlgorithmType)
            if try !otherCert.verify(otherHash) {
                throw OmniSecureStreamError.handshakeFailed("invalid cert")
            }
            otherSign = try otherCert.descriptionString()
        }

        let secret = try OmniAgreement.genSecret(myAgreement.genAgreementPrivateKey(), otherPub)
        return (otherSign, secret)
    }

    private func deriveKeys(
        keyDerivationAlgorithmType: KeyDerivationAlgorithmType,
        hashAlgorithmType: HashAlgorithmType,
        cipherAlgorithmType: CipherAlgorithmType,
        myProfile: ProfileMessage,
        otherProfile: ProfileMessage,
        secret: [UInt8]
    ) throws -> AuthResult {
        guard keyDerivationAlgorithmType.contains(.hkdf) else {
            throw OmniSecureStreamError.unsupportedAlgorithm("key derivation algorithm")
        }

        let salt = SecureUtils.xor(myProfile.sessionId, otherProfile.sessionId)
        let (keyLen, nonceLen): (Int, Int)
        if cipherAlgorithmType.contains(.aes256Gcm) {
            keyLen = 32
            nonceLen = 12
        } else {
            throw OmniSecureStreamError.unsupportedAlgorithm("cipher algorithm")
        }

        guard hashAlgorithmType.contains(.sha3_256) else {
            throw OmniSecureStreamError.unsupportedAlgorithm("hash algorithm")
        }

        let okm = try HKDF(
            password: secret,
            salt: salt,
            info: [],
            keyLength: (keyLen + nonceLen) * 2,
            variant: .sha3(.sha256)
        ).calculate()

        let (encOffset, decOffset): (Int, Int) =
            self.type == .connected
            ? (0, keyLen + nonceLen)
            : (keyLen + nonceLen, 0)

        let encKey = Array(okm[encOffset..<(encOffset + keyLen)])
        let encNonce = Array(okm[(encOffset + keyLen)..<(encOffset + keyLen + nonceLen)])
        let decKey = Array(okm[decOffset..<(decOffset + keyLen)])
        let decNonce = Array(okm[(decOffset + keyLen)..<(decOffset + keyLen + nonceLen)])

        return AuthResult(sign: nil, cipherAlgorithmType: cipherAlgorithmType, encKey: encKey, encNonce: encNonce, decKey: decKey, decNonce: decNonce)
    }

    private func genHash(profile: ProfileMessage, agreementPublicKey: OmniAgreementPublicKey, hashAlgorithmType: HashAlgorithmType) throws -> [UInt8]
    {
        guard hashAlgorithmType.contains(.sha3_256) else {
            throw OmniSecureStreamError.unsupportedAlgorithm("hash algorithm")
        }

        var hasher = SHA3(variant: .sha256)
        _ = try hasher.update(withBytes: profile.sessionId)
        _ = try hasher.update(withBytes: profile.authType.rawValue.littleEndianBytes)
        _ = try hasher.update(withBytes: profile.keyExchangeAlgorithmType.rawValue.littleEndianBytes)
        _ = try hasher.update(withBytes: profile.keyDerivationAlgorithmType.rawValue.littleEndianBytes)
        _ = try hasher.update(withBytes: profile.cipherAlgorithmType.rawValue.littleEndianBytes)
        _ = try hasher.update(withBytes: profile.hashAlgorithmType.rawValue.littleEndianBytes)
        let timestamp = Int64(agreementPublicKey.createdTime.timeIntervalSince1970).bigEndianBytes
        _ = try hasher.update(withBytes: timestamp)
        _ = try hasher.update(withBytes: agreementPublicKey.algorithmType.bitPattern.littleEndianBytes)
        _ = try hasher.update(withBytes: Array(agreementPublicKey.publicKey))

        return Array(try hasher.finish())
    }
}
