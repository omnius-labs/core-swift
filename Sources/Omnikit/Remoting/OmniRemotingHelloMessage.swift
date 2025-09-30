import Foundation
import NIO
import RocketPack

enum OmniRemotingVersion: String {
    case unknown = "unknown"
    case v1 = "v1"
}

struct OmniRemotingHelloMessage: RocketMessage, Equatable {
    public let version: OmniRemotingVersion
    public let functionId: UInt32

    public init(version: OmniRemotingVersion, functionId: UInt32) {
        self.version = version
        self.functionId = functionId
    }

    public static func pack(
        _ bytes: inout ByteBuffer, value: OmniRemotingHelloMessage, depth: UInt32
    ) throws {
        RocketMessageWriter.putString(value.version.rawValue, &bytes)
        RocketMessageWriter.putUInt32(value.functionId, &bytes)
    }

    public static func unpack(_ bytes: inout ByteBuffer, depth: UInt32) throws
        -> OmniRemotingHelloMessage
    {
        let version = OmniRemotingVersion(rawValue: try RocketMessageReader.getString(&bytes, 1024)) ?? .unknown
        let functionId = try RocketMessageReader.getUInt32(&bytes)
        return OmniRemotingHelloMessage(version: version, functionId: functionId)
    }
}
