# ActorSystemCore

## Purpose and Scope

Core is the package authority for actor addresses, invocation frames, routing,
transport delivery, lifecycle, deadlines, and system/application failure
semantics. It is the `ActorSystemCore` SwiftPM module and is used by the
Distributed and Embedded modules.

Parent: [`swift-actor-system`](../../DESIGN.md). Children: none.

## Responsibilities and Boundaries

Core validates and executes an admitted invocation, owns pending work, and
coordinates transport and actor-directory state. It does not implement a
network protocol, generate actor source, or supply a platform timer.

## Related Designs

| Design | Relationship | Contract Used | Summary | Cautions |
| --- | --- | --- | --- | --- |
| [`../../DESIGN.md`](../../DESIGN.md) | parent | package lifecycle and frame invariants | Package-level authority | Re-run Embedded validation after contract changes |
| [`../ActorSystemDistributed/DESIGN.md`](../ActorSystemDistributed/DESIGN.md) | used by | Core start/invoke/shutdown and error contracts | Distributed actor bridge | Distributed registration must not bypass Core |
| [`../ActorSystemEmbedded/DESIGN.md`](../ActorSystemEmbedded/DESIGN.md) | used by | Core invocation and lifecycle contracts | Embedded runtime facade | Clock capability remains explicit |

## Architecture

```text
ActorDirectory + ActorRouter + ActorTransport
                    |
             ActorSystemCore
        / lifecycle / pending calls
        / scheduler / deadlines
```

## Contracts and Invariants

- Every admitted call has a non-zero session and sequence identity.
- Frame version, schema, target, method, payload bounds, and lifecycle phase
  are validated before execution.
- `ActorApplicationFailure` is not converted into a successful result.
- Core receives generated target failures through its untyped error boundary.
  A typed authored application error is encoded as `ActorApplicationFailure`
  by generated Embedded host dispatch or the Distributed result handler;
  Core keeps that payload distinct from `ActorSystemError` and cancellation.
- Mutable registries and lifecycle state use `Mutex` or an actor on every
  target; no Embedded condition removes the isolation boundary.
- Binary payload storage is retained by `ActorByteBuffer`; views do not escape
  their owner.

## Runtime Flows

```text
start -> validate -> start transport consumers -> running
invoke -> validate -> local target or route -> result/failure
shutdown -> cancel owned work -> stop transports -> stopped
```

## State, Ownership, and Lifecycle

Core owns lifecycle, directory access, pending calls, inbound scheduling, and
task registries. Shutdown is terminal and releases registrations outside their
critical sections so user deinitializers can re-enter public APIs safely.

## Failure, Concurrency, and Constraints

`ActorSystemError` represents system failure and `ActorApplicationFailure`
represents a typed application payload. Core does not define or add an error
wrapper for authored typed throws; it preserves the explicit application
payload and propagates system and cancellation failures without conflation. No
`await`, transport call, or external callback occurs inside a
`Mutex.withLock` critical section. A deadline uses the injected `ActorClock`;
Embedded's unavailable default is a typed capability.

## Verification and Change Impact

`Tests/ActorSystemCoreTests` exercises codec, lifecycle, routing, failure,
shutdown, and deadline behavior. Changes to frame, ownership, lifecycle, or
clock contracts require Core tests and the generated Embedded validation.
