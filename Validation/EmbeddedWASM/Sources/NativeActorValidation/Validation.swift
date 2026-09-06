import ActorSystemCore
import ActorSystemDistributed
import ActorSystemTestSupport
import Distributed

@main
struct NativeActorValidation {
    static func main() async throws {
        let transportID = ActorTransportID("native")
        let clientEndpoint = ActorEndpoint("native-client")
        let serverEndpoint = ActorEndpoint("native-server")
        let clientTransport = LoopbackActorTransport(transportID: transportID, endpoint: clientEndpoint)
        let serverTransport = LoopbackActorTransport(transportID: transportID, endpoint: serverEndpoint)
        try clientTransport.connect(to: serverTransport)
        try serverTransport.connect(to: clientTransport)

        let clientSystem = try SwiftActorSystem(
            bootstrap: CounterFixtureActorSystemBootstrap.self,
            router: StaticActorRouter(routes: [
                TypedCounterActorSchema.descriptor.id: ActorRoute(
                    transport: transportID, endpoint: serverEndpoint
                ),
            ]),
            transports: [transportID: clientTransport],
            configuration: ActorSystemConfiguration(
                sessionIdentitySource: FixedActorSessionIdentitySource(ActorSessionID(1)),
                clock: ManualActorClock()
            )
        )
        let serverSystem = try SwiftActorSystem(
            bootstrap: CounterFixtureActorSystemBootstrap.self,
            transports: [transportID: serverTransport],
            configuration: ActorSystemConfiguration(
                sessionIdentitySource: FixedActorSessionIdentitySource(ActorSessionID(2)),
                clock: ManualActorClock()
            )
        )
        let local = TypedCounter(actorSystem: serverSystem)
        try await clientSystem.start()
        try await serverSystem.start()
        let localAccepted = try await local.validate(7)
        precondition(localAccepted == 7)
        do {
            _ = try await local.validate(-7)
            preconditionFailure("Native local typed-throws call unexpectedly succeeded")
        } catch let error as CounterError {
            guard case .rejected(let value) = error, value == -7 else {
                preconditionFailure("Native local call changed the application failure")
            }
            print("native-local-typed-failure=rejected(-7) success=7")
        }
        let remote = try TypedCounter.resolve(id: local.id, using: clientSystem)
        precondition(local.id == remote.id)
        let accepted = try await remote.validate(42)
        precondition(accepted == 42)
        print("native-remote-success=42")
        do {
            _ = try await remote.validate(-42)
            preconditionFailure("Native remote typed-throws call unexpectedly succeeded")
        } catch let error as CounterError {
            guard case .rejected(let value) = error, value == -42 else {
                preconditionFailure("Native remote call changed the application failure")
            }
            print("native-typed-failure=rejected(-42) success=42")
        }

        let cancelled = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await remote.validate(-42)
        }
        do {
            _ = try await cancelled.value
            preconditionFailure("Cancelled Native typed-throws call unexpectedly succeeded")
        } catch let error as ActorSystemError {
            precondition(error == .cancelled)
            print("native-typed-cancellation=cancelled")
        }

        try await clientSystem.shutdown()
        try await serverSystem.shutdown()
        do {
            _ = try await remote.validate(42)
            preconditionFailure("Post-shutdown Native typed-throws call unexpectedly succeeded")
        } catch let error as ActorSystemError {
            precondition(error == .shuttingDown)
            print("native-typed-system-failure=shuttingDown")
        }
    }
}
