import Foundation
import RocketPack

public enum OmniRemotingError: Error, CustomStringConvertible {
    case unsupportedType

    public var description: String {
        switch self {
        case .unsupportedType:
            return "UnexpectedProtocol"
        }
    }
}
