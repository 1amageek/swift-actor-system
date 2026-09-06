import ActorSystemCore
import ActorSystemEmbedded

private struct TypedCounterEmbeddedState {
}

public actor TypedCounter: EmbeddedActorInstance {
    public typealias ID = ActorAddress
    public typealias ActorSystem = EmbeddedActorSystem
    public nonisolated let id: ID
    public nonisolated let actorSystem: ActorSystem
    private nonisolated let location: EmbeddedActorLocation
    private var _actorSystemState: TypedCounterEmbeddedState?

    public init(actorSystem: ActorSystem) {
        self.id = actorSystem.assignID(actorType: ActorTypeID(high: 1509062301135691500, low: 15019379483999532233))
        self.actorSystem = actorSystem
        self.location = .local
        self._actorSystemState = TypedCounterEmbeddedState()
        actorSystem.embeddedBackend.registerGenerated(self, target: TypedCounterEmbeddedTarget(actor: self))
    }

    private init(id: ID, actorSystem: ActorSystem) {
        self.id = id
        self.actorSystem = actorSystem
        self.location = .remote
        self._actorSystemState = nil
    }

    public static func resolve(id: ID, using actorSystem: ActorSystem) throws -> TypedCounter {
        try actorSystem.resolve(
            id: id,
            as: TypedCounter.self
        ) {
            TypedCounter(id: id, actorSystem: actorSystem)
        }
    }

    public nonisolated final func whenLocal<Result: Sendable>(
        _ body: @escaping @Sendable (isolated TypedCounter) async throws -> Result
    ) async rethrows -> Result? {
        guard location == .local else { return nil }
        return try await _executeWhenLocal(body)
    }

    private final func _executeWhenLocal<Result: Sendable>(
        _ body: @escaping @Sendable (isolated TypedCounter) async throws -> Result
    ) async rethrows -> Result {
        try await body(self)
    }

    public nonisolated func validate(_ value: Int) async throws -> Int {
        if location == .local {
            return try await _invokeLocally_validate_1416151564143678790(value)
        }
        return try await actorSystem.invoke(
            actor: id,
            method: ActorMethodID(1416151564143678790),
            schemaFingerprint: TypedCounterActorSchema.fingerprint,
            argument: TypedCounter_validate_1416151564143678790_Arguments(value: value),
            argumentCodec: .portable(),
            resultCodec: .portable(),
            errorCodec: EmbeddedActorErrorCodec(typeID: ActorTypeID(high: 10033138577471328340, low: 3038637286077199023), codec: ActorGeneratedCodec<CounterError>.portable())
        )
    }

    fileprivate func _invokeLocally_validate_1416151564143678790(_ value: Int) async throws(CounterError) -> Int {
        if value < 0 {
                    throw .rejected(value)
                }
                return value
    }

}

extension TypedCounter: Hashable {
    public nonisolated static func == (lhs: TypedCounter, rhs: TypedCounter) -> Bool { lhs.id == rhs.id }
    public nonisolated func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

private struct TypedCounter_validate_1416151564143678790_Arguments: ActorPortableValue {
    let value: Int
    func encodeActorValue() throws -> ActorByteBuffer {
        var encoder = ActorPayloadEncoder()
        try encoder.append(message: value.encodeActorValue(), field: ActorFieldID(1))
        return encoder.finish()
    }
    static func decodeActorValue(from payload: ActorByteBuffer, options: ActorPortableDecodingOptions) throws -> Self {
        var decoder = try ActorPayloadDecoder(payload, options: options)
        guard let field0 = try decoder.nextField(), field0.id == ActorFieldID(1), field0.wireType == .message else { throw ActorSystemError.decodingFailed }
        let value0 = try Int.decodeActorValue(from: field0.payloadBuffer(), options: options.descending())
        if let _ = try decoder.nextField() { throw ActorSystemError.decodingFailed }
        return Self(value: value0)
    }
}

private struct TypedCounterEmbeddedTarget: ActorInvocationTarget {
    let actor: TypedCounter
    var address: ActorAddress { actor.id }
    let descriptor = TypedCounterActorSchema.descriptor
    func invoke(_ invocation: ActorInvocation, context: ActorInvocationContext) async throws -> ActorInvocationResult {
        switch invocation.method {
        case ActorMethodID(1416151564143678790):
            let arguments = try TypedCounter_validate_1416151564143678790_Arguments.decodeActorValue(from: invocation.payload, options: actor.actorSystem.portableDecodingOptions)
            do {
                let result = try await actor._invokeLocally_validate_1416151564143678790(arguments.value)
                return ActorInvocationResult(payload: try result.encodeActorValue())
            } catch let error as CounterError {
                throw ActorApplicationFailure(
                    typeID: ActorTypeID(high: 10033138577471328340, low: 3038637286077199023),
                    payload: try error.encodeActorValue()
                )
            }
        default:
            throw ActorSystemError.targetUnavailable(invocation.method)
        }
    }
}