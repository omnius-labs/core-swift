import Foundation
import NIO
import RocketPack

enum OmniRemotingPacketMessage<T, E>
where T: RocketMessage, E: RocketMessage & CustomStringConvertible {
    case unknown
    case `continue`(T)
    case complete(T)
    case error(E)
}

extension OmniRemotingPacketMessage: RocketMessage {
    public static func pack(
        _ bytes: inout ByteBuffer, value: OmniRemotingPacketMessage<T, E>, depth: UInt32
    ) throws {
        switch value {
        case .unknown:
            RocketMessageWriter.putUInt8(0, &bytes)
        case .continue(let value):
            RocketMessageWriter.putUInt8(1, &bytes)
            try T.pack(&bytes, value: value, depth: depth + 1)
        case .complete(let value):
            RocketMessageWriter.putUInt8(2, &bytes)
            try T.pack(&bytes, value: value, depth: depth + 1)
        case .error(let value):
            RocketMessageWriter.putUInt8(3, &bytes)
            try E.pack(&bytes, value: value, depth: depth + 1)
        }
    }

    public static func unpack(_ bytes: inout ByteBuffer, depth: UInt32) throws
        -> OmniRemotingPacketMessage<T, E>
    {
        let type = try RocketMessageReader.getUInt8(&bytes)

        switch type {
        case 0:
            return .unknown
        case 1:
            let value = try T.unpack(&bytes, depth: depth + 1)
            return .continue(value)
        case 2:
            let value = try T.unpack(&bytes, depth: depth + 1)
            return .complete(value)
        case 3:
            let value = try E.unpack(&bytes, depth: depth + 1)
            return .error(value)
        default:
            return .unknown
        }
    }
}
