import Foundation
import RocketPack

public enum OmniRemotingVersion: String {
    case unknown = "Unknown"
}

public struct HelloMessage: RocketMessage, Equatable {
    public let version: OmniRemotingVersion
    public let functionId: UInt32

    public init(version: OmniRemotingVersion, functionId: UInt32) {
        self.version = version
        self.functionId = functionId
    }

    public static func pack(
        _ writer: inout RocketMessageWriter, value: HelloMessage, depth: UInt32
    ) throws {
        writer.putString(value.version.rawValue)
        writer.putUInt32(value.functionId)
    }

    public static func unpack(_ reader: inout RocketMessageReader, depth: UInt32) throws
        -> HelloMessage
    {
        let version = try OmniRemotingVersion(rawValue: reader.getString(1024)) ?? .unknown
        let functionId = try reader.getUInt32()
        return HelloMessage(version: version, functionId: functionId)
    }
}
