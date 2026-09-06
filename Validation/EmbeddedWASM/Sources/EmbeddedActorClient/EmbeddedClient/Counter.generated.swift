import ActorSystemCore
import ActorSystemEmbedded

public actor Counter: EmbeddedActorInstance {
    public typealias ID = ActorAddress
    public typealias ActorSystem = EmbeddedActorSystem
    public nonisolated let id: ID
    public nonisolated let actorSystem: ActorSystem
    private nonisolated let location: EmbeddedActorLocation

    private init(id: ID, actorSystem: ActorSystem) {
        self.id = id
        self.actorSystem = actorSystem
        self.location = .remote
    }

    public static func resolve(id: ID, using actorSystem: ActorSystem) throws -> Counter {
        try actorSystem.resolve(
            id: id,
            as: Counter.self
        ) {
            Counter(id: id, actorSystem: actorSystem)
        }
    }

    public nonisolated final func whenLocal<Result: Sendable>(
        _ body: @escaping @Sendable (isolated Counter) async throws -> Result
    ) async rethrows -> Result? {
        guard location == .local else { return nil }
        return try await _executeWhenLocal(body)
    }

    private final func _executeWhenLocal<Result: Sendable>(
        _ body: @escaping @Sendable (isolated Counter) async throws -> Result
    ) async rethrows -> Result {
        try await body(self)
    }

    public nonisolated func increment(_ value: Int) async throws -> Int {
        return try await actorSystem.invoke(
            actor: id,
            method: ActorMethodID(9185592791354217434),
            schemaFingerprint: CounterActorSchema.fingerprint,
            argument: Counter_increment_9185592791354217434_Arguments(value: value),
            argumentCodec: .portable(),
            resultCodec: .portable()
        )
    }

    public nonisolated func validate(_ value: Int) async throws -> CounterError {
        return try await actorSystem.invoke(
            actor: id,
            method: ActorMethodID(7628941362854232182),
            schemaFingerprint: CounterActorSchema.fingerprint,
            argument: Counter_validate_7628941362854232182_Arguments(value: value),
            argumentCodec: .portable(),
            resultCodec: .portable()
        )
    }

    public nonisolated func reject() async throws -> CounterError {
        return try await actorSystem.invoke(
            actor: id,
            method: ActorMethodID(18397614679172336117),
            schemaFingerprint: CounterActorSchema.fingerprint,
            argument: ActorEmptyArguments(),
            argumentCodec: .portable(),
            resultCodec: .portable()
        )
    }

}

extension Counter: Hashable {
    public nonisolated static func == (lhs: Counter, rhs: Counter) -> Bool { lhs.id == rhs.id }
    public nonisolated func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

private struct Counter_increment_9185592791354217434_Arguments: ActorPortableValue {
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

private struct Counter_validate_7628941362854232182_Arguments: ActorPortableValue {
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
