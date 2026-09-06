# ActorSystemEmbedded

## Purpose and Scope

This module supplies the Embedded-compatible actor instance store, local
location, and `EmbeddedActorSystem` facade. It is the runtime target for
generated Embedded hosts and clients and shares Core's transport and lifecycle
contracts.

Parent: [`swift-actor-system`](../../DESIGN.md). Children: none.

## Responsibilities and Boundaries

Embedded owns actor activation and instance retention for its target. It
delegates frame validation, routing, pending work, and terminal shutdown to
Core. It does not add a network protocol or claim that Embedded has a default
deadline timer.

## Related Designs

| Design | Relationship | Contract Used | Summary | Cautions |
| --- | --- | --- | --- | --- |
| [`../../DESIGN.md`](../../DESIGN.md) | parent | Embedded capability and lifecycle invariants | Package context | Target capability is toolchain/SDK specific |
| [`../ActorSystemCore/DESIGN.md`](../ActorSystemCore/DESIGN.md) | depends on | Core invoke/start/shutdown | Execution authority | Keep shared state isolation identical |
| [`../ActorSystemGeneration/DESIGN.md`](../ActorSystemGeneration/DESIGN.md) | used by | generated host/client registration | Projection consumer | Generated schema lock must match |

## Architecture

```text
generated host/client
          |
EmbeddedActorSystem -- instance store --> ActorSystemCore
          |
     Embedded target runtime
```

## Contracts and Invariants

- Core and Embedded use the same `Mutex`-protected shared-state contract on
  native, standard WASM, and Embedded targets.
- Actor instances are registered under their stable address and are released
  after registration ownership is withdrawn.
- An explicit `ActorClock` is required for deadline behavior; the default
  Embedded clock reports `ActorClockUnavailable`.
- Shutdown is terminal and every later invocation or resolution is rejected.

## Runtime Flows

```text
init -> register generated target -> start Core
invoke -> lookup instance -> execute -> encode result/failure
shutdown -> stop Core -> release instances -> reject later calls
```

## State, Ownership, and Lifecycle

The instance store owns activated actor instances and the system owns its
registration lock. Release is performed outside the lock to permit safe
deinitialization. Core remains the owner of transport consumers and in-flight
invocation tasks.

## Failure, Concurrency, and Constraints

All mutable stores use `Mutex` or actor isolation, including Embedded builds;
`hasFeature(Embedded)` is not a synchronization decision. Application failure
payloads remain owned byte buffers until an explicit codec decodes them.

## Verification and Change Impact

`Tests/ActorSystemEmbeddedTests` covers activation, registration, invocation,
typed failure decoding, shutdown, and post-shutdown rejection. The checked-in
`Validation/EmbeddedWASM` fixture additionally proves compile, link, and Node
runtime behavior with the pinned Embedded SDK.
