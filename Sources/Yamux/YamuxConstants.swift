public enum YamuxConstants {
    public static let defaultCredit: UInt32 = 256 * 1024
    public static let defaultSplitSendSize: Int = 16 * 1024
    public static let maxAckBacklog: Int = 256

    public static let headerSize: Int = 12
    public static let maxFrameBodyLength: Int = 1024 * 1024
}
