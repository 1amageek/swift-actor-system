public enum CounterError: Error, Sendable {
    case accepted(Int)
    case rejected(Int)
}
