import Foundation
import RocketPack

public enum ProtocolErrorCode: Error, CustomStringConvertible {
    case unexpectedProtocol
    case unsupportedVersion
    case sendFailed
    case receiveFailed
    case serializationFailed
    case deserializationFailed
    case handshakeNotFinished

    public var description: String {
        switch self {
        case .unexpectedProtocol:
            return "UnexpectedProtocol"
        case .unsupportedVersion:
            return "UnsupportedVersion"
        case .sendFailed:
            return "SendFailed"
        case .receiveFailed:
            return "ReceiveFailed"
        case .serializationFailed:
            return "SerializationFailed"
        case .deserializationFailed:
            return "DeserializationFailed"
        case .handshakeNotFinished:
            return "HandshakeNotFinished"
        }
    }
}

public enum RocketMessageError<TErrorMessage>: Error
where TErrorMessage: RocketMessage & CustomStringConvertible & Sendable {
    case applicationError(TErrorMessage)
    case protocolError(ProtocolErrorCode)

    public var description: String {
        switch self {
        case .applicationError(let message):
            return "ApplicationError: \(message)"
        case .protocolError(let error):
            return "ProtocolError: \(error)"
        }
    }
}