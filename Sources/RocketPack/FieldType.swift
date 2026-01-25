import Foundation

public enum FieldType: Equatable, CustomStringConvertible, Sendable {
    case bool
    case u8
    case u16
    case u32
    case u64
    case i8
    case i16
    case i32
    case i64
    case f16
    case f32
    case f64
    case bytes
    case string
    case array
    case map
    case unknown(major: UInt8, info: UInt8)

    public var description: String {
        switch self {
        case .bool: return "bool"
        case .u8: return "u8"
        case .u16: return "u16"
        case .u32: return "u32"
        case .u64: return "u64"
        case .i8: return "i8"
        case .i16: return "i16"
        case .i32: return "i32"
        case .i64: return "i64"
        case .f16: return "f16"
        case .f32: return "f32"
        case .f64: return "f64"
        case .bytes: return "bytes"
        case .string: return "string"
        case .array: return "array"
        case .map: return "map"
        case .unknown(let major, let info):
            return "unknown(major=\(major), info=\(info))"
        }
    }
}
