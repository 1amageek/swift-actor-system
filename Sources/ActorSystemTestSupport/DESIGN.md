# ActorSystemTestSupport

## Purpose and Scope

TestSupport provides contract-preserving fixtures: `LoopbackActorTransport`,
`FailureInjectingActorTransport`, deterministic `ManualActorClock`, and static
identity/routing helpers. It is not a production transport or scheduler.

Parent: [`swift-actor-system`](../../DESIGN.md). Children: none.

## Responsibilities and Boundaries

Fixtures make success, failure, timeout, and shutdown paths reproducible while
using the same `ActorTransport`, `ActorClock`, and Core contracts as production.
They do not weaken synchronization, create fake successful data, or replace
target-level runtime validation.

## Related Designs

| Design | Relationship | Contract Used | Summary | Cautions |
| --- | --- | --- | --- | --- |
| [`../../DESIGN.md`](../../DESIGN.md) | parent | transport, clock, and lifecycle invariants | Package context | Fixtures are evidence only for their exercised paths |
| [`../ActorSystemCore/DESIGN.md`](../ActorSystemCore/DESIGN.md) | supports | Core transport and deadline contracts | Runtime under test | Keep stream and shutdown behavior faithful |
| [`../ActorSystemEmbedded/DESIGN.md`](../ActorSystemEmbedded/DESIGN.md) | supports | Embedded clock capability | Embedded deterministic tests | Manual clock injection is explicit |

## Architecture

```text
test actor system -> Loopback/FailureInjecting transport -> peer system
                 \-> ManualActorClock / Static identities
```

## Contracts and Invariants

- Loopback delivery uses `ActorFrame` and reports overload or closure as the
  corresponding transport failure.
- Every fixture's mutable state is protected by `Mutex` or actor isolation.
- `ManualActorClock` advances only when the test explicitly advances it and
  cancellation resumes sleepers with a failure.
- Fixture shutdown finishes owned `AsyncThrowingStream` continuations.

## Runtime Flows

```text
connect -> start peers -> send frame -> yield inbound -> shutdown -> finish
```

## State, Ownership, and Lifecycle

Each transport owns its stream continuation and peer link. The test owns the
fixture instances and calls shutdown; no fixture assumes process termination to
release tasks or streams.

## Failure, Concurrency, and Constraints

The fixtures preserve bounded buffering, endpoint checks, cancellation, and
typed errors. They are in-memory and do not prove socket, TLS, HTTP, or WSS
behavior.

## Verification and Change Impact

Core, Distributed, Embedded, and validation tests consume these fixtures.
Changes to fixture semantics require the affected focused tests and any
runtime validation that uses the fixture's transport path.
