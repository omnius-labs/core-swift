enum VarintError: Error {
    case invalidHeader
    case endOfInput
    case tooSmallBody
}
