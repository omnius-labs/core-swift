import Foundation
import Security

public protocol RandomBytesProvider {
    func getBytes(_ count: Int) -> [UInt8]
}

public struct RandomBytesProviderImpl: RandomBytesProvider, Sendable {
    public init() {}

    public func getBytes(_ count: Int) -> [UInt8] {
        guard count > 0 else { return [] }
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        precondition(status == errSecSuccess, "Failed to generate random bytes: \(status)")
        return bytes
    }
}
