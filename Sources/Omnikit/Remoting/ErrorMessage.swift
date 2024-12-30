import Foundation
import RocketPack

public struct OmniRemotingDefaultErrorMessage: RocketMessage, Equatable, CustomStringConvertible {
    public let type: String
    public let message: String
    public let stackTrace: String

    public init(type: String, message: String, stackTrace: String) {
        self.type = type
        self.message = message
        self.stackTrace = stackTrace
    }

    public static func pack(
        _ writer: inout RocketMessageWriter, value: OmniRemotingDefaultErrorMessage, depth: UInt32
    ) throws {
        writer.putString(value.type)
        writer.putString(value.message)
        writer.putString(value.stackTrace)
    }

    public static func unpack(_ reader: inout RocketMessageReader, depth: UInt32) throws
        -> OmniRemotingDefaultErrorMessage
    {
        let type = try reader.getString(1024)
        let message = try reader.getString(1024)
        let stackTrace = try reader.getString(1024)
        return OmniRemotingDefaultErrorMessage(type: type, message: message, stackTrace: stackTrace)
    }

    public var description: String {
        return "type: \(self.type), \(self.message)\n\(self.stackTrace)"
    }
}
