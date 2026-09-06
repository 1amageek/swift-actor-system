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
        let probeCapture = InvocationContextCapture()
        let probeSystem = EmbeddedActorSystem(
            configuration: ActorSystemConfiguration(
                sessionIdentitySource: FixedActorSessionIdentitySource(ActorSessionID(3)),
                clock: ManualActorClock(),
                inboundInterceptor: probeCapture
            ),
            callOptions: ActorCallOptions(timeout: .seconds(5))
        )
        let probeServerActor = EmbeddedActorHost.Counter(actorSystem: probeSystem)
        let probeActor = try EmbeddedActorClient.Counter.resolve(
            id: probeServerActor.id,
            using: probeSystem
        )
        try await probeSystem.start()

        let serverConfiguration = ActorSystemConfiguration(
            sessionIdentitySource: FixedActorSessionIdentitySource(ActorSessionID(2)),
            clock: serverClock,
            inboundInterceptor: StartupScopeProbeInterceptor(probe: probeActor)
        )
        let clientSystem = EmbeddedActorSystem(
            router: StaticActorRouter(
                routes: [
                    EmbeddedActorClient.Counter.actorTypeID: ActorRoute(
                        transport: clientTransportID,
                        endpoint: serverEndpoint
                    ),
                    EmbeddedActorClient.TypedCounter.actorTypeID: ActorRoute(
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
        let typedServerActor = EmbeddedActorHost.TypedCounter(actorSystem: serverSystem)
        try await ActorCallOptions.withValue(ActorCallOptions(timeout: .milliseconds(7))) {
            try await serverSystem.start()
        }
        try await clientSystem.start()
        let clientActor = try EmbeddedActorClient.Counter.resolve(
            id: serverActor.id,
            using: clientSystem
        )
        let typedClientActor = try EmbeddedActorClient.TypedCounter.resolve(
            id: typedServerActor.id,
            using: clientSystem
        )

        let accepted = try await typedClientActor.validate(42)
        precondition(accepted == 42)
        precondition(
            clientTransport.invocationTimeouts.last == 1_000_000_000,
            "Initializer call options did not reach the generated invocation"
        )
        precondition(
            probeCapture.values() == [.seconds(5)],
            "Core-owned consumers retained the start call-options scope"
        )

        let scopedAccepted = try await ActorCallOptions.withValue(.defaults) {
            try await typedClientActor.validate(42)
        }
        precondition(scopedAccepted == 42)
        guard let scopedTimeout = clientTransport.invocationTimeouts.last else {
            preconditionFailure("Task-scoped invocation did not produce a frame")
        }
        precondition(
            scopedTimeout == nil,
            "Task-scoped defaults did not override the initializer timeout"
        )

        let scopeGate = CallOptionsScopeGate(expectedEntries: 2)
        let firstConcurrentCall = Task { () -> Bool in
            do {
                let value = try await ActorCallOptions.withValue(
                    ActorCallOptions(timeout: .milliseconds(7))
                ) {
                    await scopeGate.enterAndWaitForRelease()
                    return try await typedClientActor.validate(42)
                }
                return value == 42
            } catch {
                return false
            }
        }
        let secondConcurrentCall = Task { () -> Bool in
            do {
                let value = try await ActorCallOptions.withValue(
                    ActorCallOptions(timeout: .milliseconds(11))
                ) {
                    await scopeGate.enterAndWaitForRelease()
                    return try await typedClientActor.validate(42)
                }
                return value == 42
            } catch {
                return false
            }
        }
        await scopeGate.waitUntilAllEntered()
        await scopeGate.release()
        let firstConcurrentCallSucceeded = await firstConcurrentCall.value
        let secondConcurrentCallSucceeded = await secondConcurrentCall.value
        precondition(firstConcurrentCallSucceeded)
        precondition(secondConcurrentCallSucceeded)
        let concurrentTimeouts = Array(clientTransport.invocationTimeouts.suffix(2))
        precondition(
            concurrentTimeouts.count == 2 &&
                Set(concurrentTimeouts) == Set<UInt64?>([7_000_000, 11_000_000]),
            "Concurrent task scopes did not reach the generated invocations"
        )
        print("scoped-call-options=initializer:1s, scoped:defaults")

        do {
            _ = try await typedClientActor.validate(-42)
            preconditionFailure("Generated typed-throws call unexpectedly succeeded")
        } catch let error as EmbeddedActorClient.CounterError {
            guard case .rejected(let value) = error, value == -42 else {
                preconditionFailure("Generated typed-throws call changed the application failure")
            }
            print("generated-typed-failure=rejected(-42) success=42")
        }

        let cancelled = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await typedClientActor.validate(-42)
        }
        do {
            _ = try await cancelled.value
            preconditionFailure("Cancelled typed-throws call unexpectedly succeeded")
        } catch let error as ActorSystemError {
            precondition(error == .cancelled)
            print("generated-typed-cancellation=cancelled")
        }

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
        try await probeSystem.shutdown()

        do {
            _ = try await typedClientActor.validate(42)
            preconditionFailure("Post-shutdown typed-throws call unexpectedly succeeded")
        } catch let error as ActorSystemError {
            precondition(error == .shuttingDown)
            print("generated-typed-system-failure=shuttingDown")
        }

        do {
            _ = try await clientActor.increment(1)
            preconditionFailure("Post-shutdown generated actor call unexpectedly succeeded")
        } catch let error as ActorSystemError {
            precondition(error == .shuttingDown, "Unexpected post-shutdown error: \(error)")
            print("shutdown=terminal post-shutdown=shuttingDown")
        }
    }
}

private actor CallOptionsScopeGate {
    private let expectedEntries: Int
    private var entries = 0
    private var released = false
    private var entryWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    init(expectedEntries: Int) {
        self.expectedEntries = expectedEntries
    }

    func enterAndWaitForRelease() async {
        entries += 1
        if entries == expectedEntries {
            let waiters = entryWaiters
            entryWaiters.removeAll(keepingCapacity: false)
            for waiter in waiters {
                waiter.resume()
            }
        }
        guard !released else {
            return
        }
        await withCheckedContinuation { continuation in
            releaseWaiters.append(continuation)
        }
    }

    func waitUntilAllEntered() async {
        guard entries < expectedEntries else {
            return
        }
        await withCheckedContinuation { continuation in
            entryWaiters.append(continuation)
        }
    }

    func release() {
        released = true
        let waiters = releaseWaiters
        releaseWaiters.removeAll(keepingCapacity: false)
        for waiter in waiters {
            waiter.resume()
        }
    }
}

private final class InvocationContextCapture: ActorInboundInvocationInterceptor, Sendable {
    private let storage = Mutex<[Duration?]>([])

    func values() -> [Duration?] {
        storage.withLock { $0 }
    }

    func intercept(
        _ invocation: ActorInvocation,
        context: ActorInvocationContext,
        execution: ActorInvocationExecution
    ) async throws -> ActorInvocationResult {
        _ = invocation
        storage.withLock { $0.append(context.remainingTimeout) }
        return try await execution()
    }
}

private final class StartupScopeProbeInterceptor:
    ActorInboundInvocationInterceptor,
    Sendable
{
    private let probe: EmbeddedActorClient.Counter

    init(probe: EmbeddedActorClient.Counter) {
        self.probe = probe
    }

    func intercept(
        _ invocation: ActorInvocation,
        context: ActorInvocationContext,
        execution: ActorInvocationExecution
    ) async throws -> ActorInvocationResult {
        _ = (invocation, context)
        _ = try await probe.increment(1)
        return try await execution()
    }
}

private final class BinaryEncodingTransportAdapter: ActorTransport, Sendable {
    let incoming: AsyncThrowingStream<ActorInboundFrame, Error>
    private let base: LoopbackActorTransport
    private let codec: ActorFrameCodec
    private let encodedFrames = Mutex(0)
    private let invocationTimeoutStorage = Mutex<[UInt64?]>([])

    init(base: LoopbackActorTransport, codec: ActorFrameCodec) {
        self.base = base
        self.codec = codec
        self.incoming = base.incoming
    }

    var encodedFrameCount: Int {
        encodedFrames.withLock { $0 }
    }

    var invocationTimeouts: [UInt64?] {
        invocationTimeoutStorage.withLock { $0 }
    }

    func start() async throws {
        try await base.start()
    }

    func send(_ frame: ActorFrame, to endpoint: ActorEndpoint) async throws {
        if case .invocation(let invocation) = frame {
            invocationTimeoutStorage.withLock {
                $0.append(invocation.remainingTimeoutNanoseconds)
            }
        }
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
