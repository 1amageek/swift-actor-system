import ActorSystemCore

public enum CounterError: Error, Sendable {
    case accepted(Int)
    case rejected(Int)
    static let applicationFailureTypeID = ActorTypeID(
            high: 10033138577471328340,
            low: 3038637286077199023
        )
    static func applicationFailurePayload(_ value: Int) throws -> ActorByteBuffer {
            var associated = ActorPayloadEncoder()
            try associated.append(
                message: value.encodeActorValue(),
                field: ActorFieldID(1)
            )
            var payload = ActorPayloadEncoder()
            try payload.appendEnumeration(
                caseID: 2,
                associatedValues: associated.finish(),
                field: ActorFieldID(1)
            )
            return payload.finish()
        }
}
