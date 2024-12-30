import Foundation
import NIO
import RocketPack

public enum PacketMessage<T, E>
where T: RocketMessage, E: RocketMessage & CustomStringConvertible {
    case unknown
    case `continue`(T)
    case complete(T)
    case error(E)
}

extension PacketMessage: RocketMessage {
    public static func pack(
        _ writer: inout RocketMessageWriter, value: PacketMessage<T, E>, depth: UInt32
    ) throws {
        switch value {
        case .unknown:
            writer.putUInt8(0)
        case .continue(let value):
            writer.putUInt8(1)
            try T.pack(&writer, value: value, depth: depth + 1)
        case .complete(let value):
            writer.putUInt8(1)
            try T.pack(&writer, value: value, depth: depth + 1)
        case .error(let value):
            writer.putUInt8(1)
            try E.pack(&writer, value: value, depth: depth + 1)
        }
    }

    public static func unpack(_ reader: inout RocketPack.RocketMessageReader, depth: UInt32) throws
        -> PacketMessage<T, E>
    {
        let type = try reader.getUInt8()

        switch type {
        case 0:
            return .unknown
        case 1:
            let value = try T.unpack(&reader, depth: depth + 1)
            return .continue(value)
        case 2:
            let value = try T.unpack(&reader, depth: depth + 1)
            return .complete(value)
        case 3:
            let value = try E.unpack(&reader, depth: depth + 1)
            return .error(value)
        default:
            return .unknown
        }
    }
}
