public struct YamuxConfig: Sendable {
    public private(set) var maxConnectionReceiveWindow: Int? = 1024 * 1024 * 1024
    public private(set) var maxNumStreams: Int = 512
    public private(set) var readAfterClose: Bool = true
    public private(set) var splitSendSize: Int = YamuxConstants.defaultSplitSendSize

    public init() {}

    public mutating func setMaxConnectionReceiveWindow(value: Int?) throws -> Self {
        if let value = value, value <= 0 {
            throw YamuxError.invalidConfig("MaxConnectionReceiveWindow must be > 0.")
        }

        self.maxConnectionReceiveWindow = value
        try self.ensureWindowLimits()
        return self
    }

    public mutating func setMaxNumStream(value: Int) throws -> Self {
        if value <= 0 {
            throw YamuxError.invalidConfig("MaxNumStream must be > 0.")
        }

        self.maxNumStreams = value
        try self.ensureWindowLimits()
        return self
    }

    public mutating func setReadAfterClose(value: Bool) throws -> Self {
        self.readAfterClose = value
        return self
    }

    public mutating func setSplitSendSize(value: Int) throws -> Self {
        if value <= 0 {
            throw YamuxError.invalidConfig("SplitSendSize must be > 0.")
        }

        self.splitSendSize = value
        return self
    }

    internal func ensureWindowLimits() throws {
        if let maxConnectionReceiveWindow = self.maxConnectionReceiveWindow {
            let required = maxNumStreams * Int(YamuxConstants.defaultCredit)
            if maxConnectionReceiveWindow < required {
                throw YamuxError.invalidConfig("MaxConnectionReceiveWindow must be >= 256KiB * MaxNumStreams.")
            }
        }
    }
}
