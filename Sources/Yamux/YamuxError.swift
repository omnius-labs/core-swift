public enum YamuxError: Error, Sendable {
    case connectionClosed
    case protocolError(String)
    case invalidFormat(String)
    case invalidConfig(String)
    case frameTooLarge(Int)
}
