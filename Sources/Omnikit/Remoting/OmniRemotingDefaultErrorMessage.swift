import Foundation
import NIO
import RocketPack

public struct OmniRemotingDefaultErrorMessage: RocketMessage, Equatable, CustomStringConvertible,
    Sendable
{
    public let type: String
    public let message: String
    public let stackTrace: String

    public init(type: String, message: String, stackTrace: String) {
        self.type = type
        self.message = message
        self.stackTrace = stackTrace
    }

    public init(type: String, message: String) {
        self.type = type
        self.message = message
        self.stackTrace = Thread.callStackSymbols.joined(separator: "\n")
    }

    public static func pack(
        _ bytes: inout ByteBuffer, value: OmniRemotingDefaultErrorMessage, depth: UInt32
    ) throws {
        RocketMessageWriter.putString(value.type, &bytes)
        RocketMessageWriter.putString(value.message, &bytes)
        RocketMessageWriter.putString(value.stackTrace, &bytes)
    }

    public static func unpack(_ bytes: inout ByteBuffer, depth: UInt32) throws
        -> OmniRemotingDefaultErrorMessage
    {
        let type = try RocketMessageReader.getString(&bytes, 1024)
        let message = try RocketMessageReader.getString(&bytes, 1024)
        let stackTrace = try RocketMessageReader.getString(&bytes, 1024)
        return OmniRemotingDefaultErrorMessage(type: type, message: message, stackTrace: stackTrace)
    }

    public var description: String {
        return "type: \(self.type), \(self.message)\n\(self.stackTrace)"
    }
}
