extension FixedWidthInteger {
    public var littleEndianBytes: [UInt8] {
        withUnsafeBytes(of: self.littleEndian, Array.init)
    }

    public var bigEndianBytes: [UInt8] {
        withUnsafeBytes(of: self.bigEndian, Array.init)
    }
}
