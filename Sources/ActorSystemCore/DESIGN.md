# ActorSystemCore

## Purpose and Scope

Core is the package authority for actor addresses, invocation frames, routing,
transport delivery, lifecycle, deadlines, and system/application failure
semantics. It is the `ActorSystemCore` SwiftPM module and is used by the
Distributed and Embedded modules.

Parent: [`swift-actor-system`](../../DESIGN.md). Children: none.

## Responsibilities and Boundaries

Core validates and executes an admitted invocation, owns pending work,
coordinates transport and actor-directory state, and defines the task-scoped
`ActorCallOptions` value consumed by the public facades. It does not implement
a network protocol, generate actor source, or supply a platform timer.

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
- `ActorCallOptions.withValue(_:operation:)` installs an immutable task-local
  value for the duration of one asynchronous operation. Presence of the scope,
  rather than a non-`nil` timeout, determines precedence, so `.defaults`
  disables an initializer timeout within that scope. Nested scopes restore the
  previous value and concurrent task scopes do not mutate one another or an
  actor system's initializer configuration.
- `withValue` is the only new public operation and is asynchronous
  `nonisolated(nonsending)`. Its storage and current-value access remain
  private/package implementation details; one package helper resolves
  `scoped ?? initializerDefault` for both facades.
- The dynamic value applies only to actor calls lexically initiated within the
  scoped operation. Core's owned start task clears it before `performStart`, so
  transport consumers and later inbound scheduling cannot retain the caller's
  temporary policy. This clear uses a package-only helper and remains nested
  inside the existing `ActorOwnedTaskContext`; it does not detach tasks or
  change Core's ownership ancestry.

## Runtime Flows

```text
start -> validate -> start transport consumers -> running
invoke -> validate -> local target or route -> result/failure
shutdown -> cancel owned work -> stop transports -> stopped
```

## State, Ownership, and Lifecycle

Core owns lifecycle, directory access, pending calls, inbound scheduling, and
task registries. Shutdown is terminal and releases registrations outside their
critical sections so user deinitializers can re-enter public APIs safely. Call
options use task-local dynamic scope rather than a mutable process-wide or
actor-system registry; the runtime restores the previous scope on normal
return, thrown error, and cancellation. Core-owned transport consumers begin
with no call-options scope even when `start()` or automatic facade startup was
entered inside one; their lifetime and Actor-owned task identity are unchanged.

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
shutdown, deadline behavior, and task-scoped option restoration/isolation.
The Distributed and Embedded facade tests prove that an active scope wins over
their initializer default and that no scope preserves existing behavior.
One Core loopback regression starts inside a scope, exits it, then has a later
inbound interceptor resolve an explicit fallback. It must observe that fallback
rather than the expired start scope. Together with the facade precedence tests,
this proves startup isolation and facade selection without claiming that the
Core-only test executes a second facade. Source review separately confirms that
the clear remains nested inside the existing Actor-owned task context.
Changes to frame, ownership, lifecycle, call-option, or clock contracts require
Core tests and the generated Embedded validation.
