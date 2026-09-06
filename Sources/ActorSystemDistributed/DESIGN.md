# ActorSystemDistributed

## Purpose and Scope

This module adapts the package runtime to Swift's `DistributedActorSystem`
protocol. It is the owner of distributed-actor registration, invocation
encoding/decoding, result handling, and the public `SwiftActorSystem` facade.

Parent: [`swift-actor-system`](../../DESIGN.md). Children: none.

## Responsibilities and Boundaries

The module maps distributed actor operations to Core invocations and keeps
registration/type/codec state consistent. It does not own wire framing,
transport lifecycle, or generated source; those remain Core and Generation
responsibilities.

## Related Designs

| Design | Relationship | Contract Used | Summary | Cautions |
| --- | --- | --- | --- | --- |
| [`../../DESIGN.md`](../../DESIGN.md) | parent | package actor and failure invariants | Module context | Preserve transport neutrality |
| [`../ActorSystemCore/DESIGN.md`](../ActorSystemCore/DESIGN.md) | depends on | Core invocation and lifecycle | Runtime execution authority | Do not duplicate pending-call state |
| [`../ActorSystemGeneration/DESIGN.md`](../ActorSystemGeneration/DESIGN.md) | used by | generated actor registration shape | Generated clients and hosts | Generated code must use public registration contracts |

## Architecture

```text
DistributedActorSystem
        |
SwiftActorSystem -- registries/codecs --> ActorSystemCore
        |
  invocation encoder/decoder/result handler
```

## Contracts and Invariants

- `SwiftActorSystem` exposes Core's lifecycle and failure semantics without
  silently changing errors.
- Registration is validated, sealed, and owned by the system that installed
  it; duplicate ownership is rejected.
- Codec registries are snapshotted at initialization, so later caller
  mutation cannot alter the wire contract.
- Actor identity and schema values are stable for the lifetime of a system.

## Runtime Flows

```text
register types/bootstraps -> start Core -> resolve or instantiate actor
distributed call -> encode arguments -> Core invoke -> decode result/failure
shutdown -> seal registrations -> Core terminal shutdown
```

## State, Ownership, and Lifecycle

The facade owns local distributed actor references and registration state while
Core owns transport and invocation tasks. Registration becomes sealed during
startup and terminated during shutdown; no new actor work is admitted after
termination.

## Failure, Concurrency, and Constraints

Registration and local actor state are protected by `Mutex` or actor-owned
state. Distributed invocation preserves the distinction between system
failure, remote failure, and an explicitly codec-decoded application failure.
The module does not infer an Embedded timer or thread model.

## Verification and Change Impact

`Tests/ActorSystemDistributedTests` covers execution, registration, codec
lookups, duplicate ownership, and shutdown paths. Changes to distributed
mapping require those tests plus Core and Embedded generated validation.
