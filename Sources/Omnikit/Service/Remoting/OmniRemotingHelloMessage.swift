import Foundation
import NIO
import RocketPack

enum OmniRemotingVersion: String {
    case unknown = "unknown"
    case v1 = "v1"
}

struct OmniRemotingHelloMessage: Equatable {
    public let version: OmniRemotingVersion
    public let functionId: UInt32

    public init(version: OmniRemotingVersion, functionId: UInt32) {
        self.version = version
        self.functionId = functionId
    }
}

extension OmniRemotingHelloMessage: RocketPackStruct {
    static func pack(encoder: any RocketPack.RocketPackEncoder, value: OmniRemotingHelloMessage) throws {
        try encoder.writeMap(2)

        try encoder.writeU64(0)
        try encoder.writeString(value.version.rawValue)

        try encoder.writeU64(1)
        try encoder.writeU32(value.functionId)
    }

    static func unpack(decoder: any RocketPack.RocketPackDecoder) throws -> OmniRemotingHelloMessage {
        var version: OmniRemotingVersion?
        var functionId: UInt32?

        let count = try decoder.readMap()

        for _ in 0..<count {
            switch try decoder.readU64() {
            case 0:
                let rawVersion = try decoder.readString()
                guard let parsedVersion = OmniRemotingVersion(rawValue: rawVersion) else {
                    throw RocketPackDecoderError.other("parse error")
                }
                version = parsedVersion
            case 1:
                functionId = try decoder.readU32()
            default:
                try decoder.skipField()
            }
        }

        guard let version else {
            throw RocketPackDecoderError.other("missing field: version")
        }

        guard let functionId else {
            throw RocketPackDecoderError.other("missing field: function_id")
        }

        return OmniRemotingHelloMessage(version: version, functionId: functionId)
    }
}
