# ActorSystemCompatibility

## Purpose and Scope

Compatibility is the explicit adapter for the legacy `ActorRuntime` protocol
and JSON actor gateway. It preserves the old ingress shape while routing into
the current Core contracts.

Parent: [`swift-actor-system`](../../DESIGN.md). Children: none.

## Responsibilities and Boundaries

The module validates legacy descriptors, maps legacy targets to stable actor
addresses, and translates legacy envelopes to Core invocations. It does not
change Core wire semantics or pretend the legacy protocol can decode typed
application failures it does not carry.

## Related Designs

| Design | Relationship | Contract Used | Summary | Cautions |
| --- | --- | --- | --- | --- |
| [`../../DESIGN.md`](../../DESIGN.md) | parent | Core failure and lifecycle contract | Package context | Compatibility is an adapter, not a second runtime |
| [`../ActorSystemCore/DESIGN.md`](../ActorSystemCore/DESIGN.md) | depends on | address, invoke, and error contracts | Execution authority | Do not bypass validation |

## Architecture

```text
legacy JSON/envelope -> descriptor validation -> Core invocation
                                  |
                         legacy result translation
```

## Contracts and Invariants

- Legacy contract prefixes and method identifiers are non-empty and unique.
- A legacy target maps only to the descriptor's declared actor type and schema.
- Legacy system failures are translated explicitly; unsupported typed
  application failure decoding is reported as a failure.
- Legacy shutdown terminates pending continuations and rejects new work.

## Runtime Flows

```text
start gateway -> admit legacy request -> map/decode -> Core invoke
result/failure -> encode legacy envelope -> resume caller
shutdown -> fail pending requests -> finish gateway
```

## State, Ownership, and Lifecycle

The gateway owns pending legacy continuations and its transport stream. Core
owns the resulting actor invocation. Gateway shutdown releases pending
continuations exactly once and does not own Core's shutdown operation.

## Failure, Concurrency, and Constraints

Pending state is synchronized with `Mutex`; continuations are resumed outside
critical sections. Unsupported legacy representations never become successful
default values, and all JSON/Data conversion remains at the compatibility
boundary.

## Verification and Change Impact

`Tests/ActorSystemCompatibilityTests` covers descriptor validation, request and
result mapping, unsupported typed failures, and shutdown. Changes require Core
failure-path tests because the adapter consumes Core's public contract.
