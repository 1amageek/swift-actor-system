import ActorSystemCore
import ActorSystemEmbedded
import ActorSystemTestSupport
import EmbeddedActorClient
import EmbeddedActorHost
import Synchronization

@main
struct EmbeddedActorValidation {
    static func main() async throws {
#if hasFeature(Embedded)
        do {
            try await ContinuousActorClock().sleep(for: .milliseconds(1))
            preconditionFailure("Embedded ContinuousActorClock unexpectedly supplied a timer")
        } catch is ActorClockUnavailable {
            print("clock=unavailable")
        } catch {
            preconditionFailure("Unexpected Embedded clock failure")
        }
#else
        print("clock=native")
#endif

        let clientClock = ManualActorClock()
        let serverClock = ManualActorClock()
        let clientTransportID = ActorTransportID("embedded-client")
        let serverTransportID = ActorTransportID("embedded-server")
        let clientEndpoint = ActorEndpoint("embedded-client")
        let serverEndpoint = ActorEndpoint("embedded-server")
        let wireCodec = ActorFrameCodec(
            maximumFrameBytes: 1_048_576,
            maximumPayloadBytes: 1_000_000,
            maximumIdentityBytes: 4_096
        )
        let clientBase = LoopbackActorTransport(
            transportID: clientTransportID,
            endpoint: clientEndpoint
        )
        let serverBase = LoopbackActorTransport(
            transportID: serverTransportID,
            endpoint: serverEndpoint
        )
        try clientBase.connect(to: serverBase)
        try serverBase.connect(to: clientBase)
        let clientTransport = BinaryEncodingTransportAdapter(
            base: clientBase,
            codec: wireCodec
        )
        let serverTransport = BinaryEncodingTransportAdapter(
            base: serverBase,
            codec: wireCodec
        )

        let clientConfiguration = ActorSystemConfiguration(
            sessionIdentitySource: FixedActorSessionIdentitySource(ActorSessionID(1)),
            clock: clientClock
        )
        let serverConfiguration = ActorSystemConfiguration(
            sessionIdentitySource: FixedActorSessionIdentitySource(ActorSessionID(2)),
            clock: serverClock
        )
        let clientSystem = EmbeddedActorSystem(
            router: StaticActorRouter(
                routes: [
                    EmbeddedActorClient.Counter.actorTypeID: ActorRoute(
                        transport: clientTransportID,
                        endpoint: serverEndpoint
                    ),
                ]
            ),
            transports: [clientTransportID: clientTransport],
            configuration: clientConfiguration,
            callOptions: ActorCallOptions(timeout: .seconds(1))
        )
        let serverSystem = EmbeddedActorSystem(
            transports: [serverTransportID: serverTransport],
            configuration: serverConfiguration,
            callOptions: ActorCallOptions(timeout: .seconds(1))
        )

        let serverActor = EmbeddedActorHost.Counter(actorSystem: serverSystem)
        try await serverSystem.start()
        try await clientSystem.start()
        let clientActor = try EmbeddedActorClient.Counter.resolve(
            id: serverActor.id,
            using: clientSystem
        )

        let incremented = try await clientActor.increment(41)
        precondition(incremented == 42, "Generated actor call returned \(incremented)")

        do {
            _ = try await clientActor.reject()
            preconditionFailure("Generated untyped-throws failure call unexpectedly succeeded")
        } catch let error as ActorSystemError {
            precondition(
                error == .remoteFailure(
                    ActorRemoteFailure(code: ActorSystemErrorCode.remoteFailure.rawValue)
                ),
                "Unexpected generated failure mapping: \(error)"
            )
            print("generated-untyped-failure=remoteFailure")
        }

        let failureTypeID = ActorTypeID(
            high: 10033138577471328340,
            low: 3038637286077199023
        )
        do {
            let _: EmbeddedActorClient.CounterError = try await clientSystem.invoke(
                actor: serverActor.id,
                method: ActorMethodID(18397614679172336117),
                schemaFingerprint: EmbeddedActorClient.Counter.actorSchemaFingerprint,
                argument: ActorEmptyArguments(),
                argumentCodec: .portable(),
                resultCodec: .portable(EmbeddedActorClient.CounterError.self),
                errorCodec: EmbeddedActorErrorCodec(
                    typeID: failureTypeID,
                    codec: .portable(EmbeddedActorClient.CounterError.self)
                )
            )
            preconditionFailure("Generated actor failure call unexpectedly succeeded")
        } catch let error as EmbeddedActorClient.CounterError {
            guard case .rejected(let value) = error, value == -1 else {
                preconditionFailure("Unexpected typed application failure: \(error)")
            }
            print("typed-wire-failure=rejected(-1)")
        }

        precondition(clientTransport.encodedFrameCount > 0)
        precondition(serverTransport.encodedFrameCount > 0)
        print("binary-frames=client:\(clientTransport.encodedFrameCount),server:\(serverTransport.encodedFrameCount)")

        try await clientSystem.shutdown()
        try await serverSystem.shutdown()

        do {
            _ = try await clientActor.increment(1)
            preconditionFailure("Post-shutdown generated actor call unexpectedly succeeded")
        } catch let error as ActorSystemError {
            precondition(error == .shuttingDown, "Unexpected post-shutdown error: \(error)")
            print("shutdown=terminal post-shutdown=shuttingDown")
        }
    }
}

private final class BinaryEncodingTransportAdapter: ActorTransport, Sendable {
    let incoming: AsyncThrowingStream<ActorInboundFrame, Error>
    private let base: LoopbackActorTransport
    private let codec: ActorFrameCodec
    private let encodedFrames = Mutex(0)

    init(base: LoopbackActorTransport, codec: ActorFrameCodec) {
        self.base = base
        self.codec = codec
        self.incoming = base.incoming
    }

    var encodedFrameCount: Int {
        encodedFrames.withLock { $0 }
    }

    func start() async throws {
        try await base.start()
    }

    func send(_ frame: ActorFrame, to endpoint: ActorEndpoint) async throws {
        let bytes = try codec.encode(frame)
        let decoded = try codec.decode(bytes)
        encodedFrames.withLock { $0 += 1 }
        try await base.send(decoded, to: endpoint)
    }

    func setEndpointTerminationHandler(
        _ handler: (@Sendable (ActorEndpoint, ActorSystemError) async -> Void)?
    ) async {
        await base.setEndpointTerminationHandler(handler)
    }

    func shutdown() async {
        await base.shutdown()
    }
}
