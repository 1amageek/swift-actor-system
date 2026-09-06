import ActorSystemCore

enum CounterActorSchema {
    static let typeID = ActorTypeID(high: 1273564343073864120, low: 3642567731750926847)
    static let fingerprint = ActorSchemaFingerprint(high: 541993513410613368, low: 14780909217542817265)
    static let increment_9185592791354217434MethodID = ActorMethodID(9185592791354217434)
    static let reject_18397614679172336117MethodID = ActorMethodID(18397614679172336117)
    static let validate_7628941362854232182MethodID = ActorMethodID(7628941362854232182)
    static let descriptor = ActorTypeDescriptor(
        id: typeID,
        schemaFingerprint: fingerprint,
        methods: [
            ActorMethodDescriptor(id: ActorMethodID(9185592791354217434), parameterTypeIDs: [ActorTypeID(high: 17136416053037652511, low: 11586992519881825816)], resultTypeID: ActorTypeID(high: 17136416053037652511, low: 11586992519881825816), errorTypeID: nil),
            ActorMethodDescriptor(id: ActorMethodID(18397614679172336117), parameterTypeIDs: [], resultTypeID: ActorTypeID(high: 10033138577471328340, low: 3038637286077199023), errorTypeID: nil),
            ActorMethodDescriptor(id: ActorMethodID(7628941362854232182), parameterTypeIDs: [ActorTypeID(high: 17136416053037652511, low: 11586992519881825816)], resultTypeID: ActorTypeID(high: 10033138577471328340, low: 3038637286077199023), errorTypeID: nil),
        ]
    )
}

extension Counter: ActorSystemReference {
    public nonisolated static var actorTypeID: ActorTypeID { CounterActorSchema.typeID }
    public nonisolated static var actorSchemaFingerprint: ActorSchemaFingerprint { CounterActorSchema.fingerprint }
    public nonisolated static var actorTypeDescriptor: ActorTypeDescriptor { CounterActorSchema.descriptor }
}

public enum CounterFixtureActorSchemaModule: ActorSchemaModule {
    public static let actorTypeDescriptors: [ActorTypeDescriptor] = [
        CounterActorSchema.descriptor,
    ]
}
