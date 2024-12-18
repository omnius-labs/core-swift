public enum RocketMessageError: Error {
    case tooLarge
    case endOfInput
    case invalidUtf8
}

public enum VarintError: Error {
    case invalidHeader
    case endOfInput
    case tooSmallBody
}
