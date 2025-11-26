import Foundation
import Security

enum SecureUtils {
    static func incrementBytes(_ bytes: inout [UInt8]) {
        for i in 0..<bytes.count {
            if bytes[i] == 0xFF {
                bytes[i] = 0
            } else {
                bytes[i] &+= 1
                break
            }
        }
    }

    static func xor(_ lhs: [UInt8], _ rhs: [UInt8]) -> [UInt8] {
        let count = min(lhs.count, rhs.count)
        var result = [UInt8](repeating: 0, count: count)
        for i in 0..<count {
            result[i] = lhs[i] ^ rhs[i]
        }
        return result
    }

    static func base64Url(_ data: Data) -> String {
        let base = data.base64EncodedString()
        return
            base
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
