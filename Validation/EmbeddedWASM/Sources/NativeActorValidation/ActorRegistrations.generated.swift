import ActorSystemCore
import ActorSystemDistributed

public enum CounterFixtureActorSystemBootstrap: SwiftActorSystemBootstrap {
    public static let bootstrapIdentifier = "embedded-actor-validation:CounterFixture"
    public static let actorTypeDescriptors = CounterFixtureActorSchemaModule.actorTypeDescriptors
    public static let dependencies: [any SwiftActorSystemBootstrap.Type] = []

    public static func register(in actorSystem: SwiftActorSystem) throws {
        try actorSystem.registerCodec(CounterError.self, typeID: ActorTypeID(high: 10033138577471328340, low: 3038637286077199023), codec: .portable())
        try actorSystem.registerCodec(Int.self, typeID: ActorTypeID(high: 17136416053037652511, low: 11586992519881825816), codec: .portable())
        let counterAliases = try ActorTargetAliasTable(
            toolchainFingerprint: "swiftc-d2d377a9b66c040c0cb1cfbd1250d9e3",
            aliases: [
                "$s14CounterFixture0A0C9incrementyS2iYaKFTE": ActorMethodID(9185592791354217434),
                "$s14CounterFixture0A0C6rejectAA0A5ErrorOyYaKFTE": ActorMethodID(18397614679172336117),
                "$s14CounterFixture0A0C8validateyAA0A5ErrorOSiYaKFTE": ActorMethodID(7628941362854232182),
            ]
        )
        try actorSystem.register(
            DistributedActorTypeRegistration(
                Counter.self,
                descriptor: CounterActorSchema.descriptor,
                aliases: counterAliases
            ).eraseToAnyRegistration()
        )
        let typedCounterAliases = try ActorTargetAliasTable(
            toolchainFingerprint: "swiftc-d2d377a9b66c040c0cb1cfbd1250d9e3",
            aliases: [
                "$s14CounterFixture05TypedA0C8validateyS2iYaKFTE": ActorMethodID(1416151564143678790),
            ]
        )
        try actorSystem.register(
            DistributedActorTypeRegistration(
                TypedCounter.self,
                descriptor: TypedCounterActorSchema.descriptor,
                aliases: typedCounterAliases
            ).eraseToAnyRegistration()
        )
    }
}

extension Counter: SwiftActorSystemBootstrapProvider {
    public nonisolated static var actorSystemBootstrap: any SwiftActorSystemBootstrap.Type { CounterFixtureActorSystemBootstrap.self }
}

extension TypedCounter: SwiftActorSystemBootstrapProvider {
    public nonisolated static var actorSystemBootstrap: any SwiftActorSystemBootstrap.Type { CounterFixtureActorSystemBootstrap.self }
}
