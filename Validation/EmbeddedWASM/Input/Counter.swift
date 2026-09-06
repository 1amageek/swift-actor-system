import ActorSystemCore
import ActorSystemDistributed
import Distributed

public enum CounterError: Error, Codable, Sendable {
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

public distributed actor Counter {
    public typealias ActorSystem = SwiftActorSystem

    public init(actorSystem: ActorSystem) {
        self.actorSystem = actorSystem
    }

    public distributed func increment(_ value: Int) async throws -> Int {
        value + 1
    }

    public distributed func validate(_ value: Int) async throws -> CounterError {
        if value < 0 {
            throw ActorApplicationFailure(
                typeID: CounterError.applicationFailureTypeID,
                payload: try CounterError.applicationFailurePayload(value)
            )
        }
        return .accepted(value)
    }

    public distributed func reject() async throws -> CounterError {
        throw ActorApplicationFailure(
            typeID: CounterError.applicationFailureTypeID,
            payload: try CounterError.applicationFailurePayload(-1)
        )
    }
}
