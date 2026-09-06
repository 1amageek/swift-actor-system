# swift-actor-system

## Purpose and Scope

This package owns the transport-independent actor runtime, source-generation
contract, and native/Embedded projections exported by this repository. It is
the package root design and indexes the module boundaries implemented by the
SwiftPM targets in `Package.swift`.

Parent: none; this repository is an independently maintained package.
Children: `ActorSystemCore`, `ActorSystemDistributed`, `ActorSystemEmbedded`,
`ActorSystemGeneration`, `ActorSystemBuildSupport`, `ActorSystemCompatibility`,
`ActorSystemTestSupport`, and `ActorSystemTool` modules.

## Responsibilities and Boundaries

The package owns actor identity, lifecycle, invocation frames, routing,
transport contracts, source schema locks, generated codecs, and target
projections. It does not own a network protocol implementation, a platform
timer, a WebSocket implementation, or application actor business state.

Generated projections preserve an authored typed method effect where the
language projection requires it, while every runtime remote call keeps an
untyped system-error boundary so system and cancellation failures remain
representable alongside an application failure.

`ActorSystemCore` is the authority for lifecycle and call state. Transports
only deliver `ActorFrame` values and report stream/lifecycle events. Generated
source owns the target-specific actor surface; it does not replace Core's
validation or failure mapping.

## Related Designs

| Design | Relationship | Contract Used | Summary | Cautions |
| --- | --- | --- | --- | --- |
| SwiftWeb consumer | used by | released package products | SwiftWeb may consume this package through its public products | This standalone package has no source-parent ownership |
| [`Sources/ActorSystemCore/DESIGN.md`](Sources/ActorSystemCore/DESIGN.md) | child | frame, lifecycle, router, transport, and error contracts | Core state and wire semantics | Every target uses the same Mutex ownership model |
| [`Sources/ActorSystemDistributed/DESIGN.md`](Sources/ActorSystemDistributed/DESIGN.md) | child | `DistributedActorSystem` bridge and registration | Swift distributed-actor surface over Core | Generated calls retain Core failure and lifecycle semantics |
| [`Sources/ActorSystemEmbedded/DESIGN.md`](Sources/ActorSystemEmbedded/DESIGN.md) | child | generated Embedded registration and invocation | Embedded actor runtime facade | Timer capability is injected; the default Embedded clock is unavailable |
| [`Sources/ActorSystemGeneration/DESIGN.md`](Sources/ActorSystemGeneration/DESIGN.md) | child | schema lock and generated-source manifest | Authoritative generation and target projection | Projection requires an unchanged schema lock |
| [`Sources/ActorSystemBuildSupport/DESIGN.md`](Sources/ActorSystemBuildSupport/DESIGN.md) | child | compiler-target and toolchain resolution | Build-time environment bridge | Target identity must match the selected compiler and SDK |
| [`Sources/ActorSystemCompatibility/DESIGN.md`](Sources/ActorSystemCompatibility/DESIGN.md) | child | legacy actor gateway and bridge contracts | Explicit legacy protocol adapter | Legacy typed failures remain explicit unsupported outcomes |
| [`Sources/ActorSystemTestSupport/DESIGN.md`](Sources/ActorSystemTestSupport/DESIGN.md) | child | deterministic clocks and in-memory transports | Contract fixtures for package tests | Fixtures must preserve transport and lifecycle failure semantics |
| [`Sources/ActorSystemTool/DESIGN.md`](Sources/ActorSystemTool/DESIGN.md) | child | command-line generation and projection entry point | User-facing build tool | CLI delegates validation to package generation contracts |
| `Validation/EmbeddedWASM` | verification consumer | generated host/client and lifecycle contracts | End-to-end Embedded validation fixture | Runtime evidence is limited to the pinned toolchain and Node runner |

## Architecture

```text
Actor source
    |
    +--> ActorSystemGeneration --> ActorSchema.lock + generated source
    |
    v
ActorSystemEmbedded / ActorSystemDistributed
    |
    v
ActorSystemCore
    +--> Mutex-owned lifecycle, directory, pending calls, schedulers
    +--> ActorRouter --> ActorTransport --> peer
    +--> ActorFrameCodec (binary boundary)
```

## Contracts and Invariants

- A call has one non-zero session identity and one non-zero sequence identity.
- Core validates actor address, schema fingerprint, method, payload bounds, and
  lifecycle state before admitting work.
- `ActorApplicationFailure` remains distinct from system failure across the
  invocation and result paths; an application boundary may decode it with an
  explicit typed codec.
- An authored `throws(ErrorType)` is accepted only when `ErrorType` is in the
  exported portable schema. Native/local generated dispatch keeps that typed
  signature. Standard client declarations retain the authored effect for
  compiler target identity, while their generated remote call path and
  Embedded remote entry points preserve untyped system and cancellation
  failures.
- Mutable lifecycle, directory, registration, transport, and scheduler state
  is protected by its owner `Mutex` or actor on every target. Embedded feature
  detection never removes this isolation.
- `ActorByteBuffer` retains storage while views are borrowed. Binary encoding
  is performed only at the transport/wire boundary; Core passes frame payload
  views without eager `Data` materialization.
- Shutdown is terminal: it drains owned tasks, releases registrations outside
  registration critical sections, and rejects later invocation/resolve work.
- Embedded projections use only capabilities available from the selected
  Embedded SDK. Deadline behavior requires an injected `ActorClock`; the
  default `ContinuousActorClock` reports `ActorClockUnavailable` on Embedded.

## Runtime Flows

```text
start -> validate configuration -> start transports -> consume incoming
  |
invoke -> encode argument -> local target or route -> transport -> pending call
  |                                                                  |
  +<---------------- result / application failure / system failure ---+
  |
requestShutdown -> cancel/fail calls -> stop consumers/transports -> stopped
```

Generated Embedded hosts register their target during initialization. Generated
clients resolve an address and select local execution or Core's routed invoke
path. The validation fixture adds deterministic clock injection and exercises
both success and typed failure outcomes.

## State, Ownership, and Lifecycle

Core owns the lifecycle coordinator, pending-call registry, inbound scheduler,
outbound task registry, and directory. `EmbeddedActorSystem` owns the instance
store and registration lock, then delegates invocation and shutdown semantics
to Core. A transport owns its stream continuation and delivery state. The
shutdown operation releases actor instances after leaving the registration lock
so deinitializers may safely re-enter the public system boundary.

## Failure, Concurrency, and Constraints

System failures use `ActorSystemError` and are encoded with an explicit error
code. Application failures carry a type ID and owned payload; an absent or
mismatched codec is a decoding failure or explicit remote failure, never a
successful default value. No `await` occurs inside a `Mutex.withLock` critical
section. Stream owners finish `AsyncThrowingStream` continuations during
shutdown.

## Verification and Change Impact

| Contract | Evidence owner | Required evidence |
| --- | --- | --- |
| Core frame/lifecycle/error behavior | Core tests | focused native tests and source-path review |
| Generation and projection stability | Generation/BuildSupport tests | schema lock reconciliation and generated-source checks |
| Embedded registration and shutdown | Embedded tests | typed failure, release, and post-shutdown tests |
| Embedded target capability | validation fixture | pinned SDK compile/link/runtime execution |

Changes to Core's public error, ownership, frame, or lifecycle contracts require
re-running all direct module tests and the Embedded fixture. Changes to the
generator require authoritative generation plus both Embedded projections and
manifest verification.
