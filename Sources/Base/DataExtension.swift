import Foundation

extension Data {
    @inlinable
    public func readUInt32LittleEndian(at offset: Int = 0) -> UInt32? {
        let end = offset &+ MemoryLayout<UInt32>.size
        guard offset >= 0, end <= count else { return nil }

        return withUnsafeBytes { raw -> UInt32 in
            // Data の先頭は 4byte アラインされている保証がないので loadUnaligned を使う
            let v = raw.loadUnaligned(fromByteOffset: offset, as: UInt32.self)
            return UInt32(littleEndian: v)
        }
    }

    @inlinable
    public func readString(encoding: String.Encoding = .utf8) -> String {
        return String(data: self, encoding: encoding) ?? ""
    }
}
