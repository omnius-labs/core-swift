public enum RocketMessageError: Error {
    case endOfInput
    case limitExceeded
    case tooSmallBody
    case invalidUtf8
}

public enum VarintError: Error {
    case endOfInput
    case invalidHeader
    case tooSmallBody
}
