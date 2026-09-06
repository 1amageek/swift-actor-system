# ActorSystemGeneration

## Purpose and Scope

Generation owns source scanning, portable actor schema modeling, schema-lock
reconciliation, generated source writing, and native/Embedded projection. It
is the authority behind the `actor-system` generated host and client sources.

Parent: [`swift-actor-system`](../../DESIGN.md). Children: none.

## Responsibilities and Boundaries

The module validates actor declarations and emits deterministic codecs,
registration, and proxy sources for a selected profile. It does not execute
actors, own transport state, or invent a typed-throws surface the source
contract rejects.

## Related Designs

| Design | Relationship | Contract Used | Summary | Cautions |
| --- | --- | --- | --- | --- |
| [`../../DESIGN.md`](../../DESIGN.md) | parent | schema and projection invariants | Package context | Generated artifacts are derived, not handwritten |
| [`../ActorSystemBuildSupport/DESIGN.md`](../ActorSystemBuildSupport/DESIGN.md) | used by | compiler target and fingerprint | Build environment input | Compiler and SDK must be paired |
| [`../ActorSystemEmbedded/DESIGN.md`](../ActorSystemEmbedded/DESIGN.md) | used by | Embedded registration/invocation | Generated runtime consumer | Verify target-level behavior, not syntax only |

## Architecture

```text
Swift actor source -> scanner/validators -> schema lock
                                  |
                         source writer/projector
                                  |
                    native / embedded host + client
```

## Contracts and Invariants

- A generated file is accepted only when its schema lock and toolchain
  fingerprint match the request.
- Generation is deterministic for the same sources, profile, lock, and
  compiler environment.
- Unsupported effects or portable types are explicit generation failures.
- Generated untyped `throws` preserves system/remote failure mapping; a typed
  application decode is performed only at an explicit codec boundary.
- Associated-value enum codecs bind each decoded payload in the generated
  switch arm.

## Runtime Flows

```text
scan -> validate portability/effects -> reconcile lock -> emit manifest/sources
project -> verify lock/fingerprint -> emit target-specific files
```

## State, Ownership, and Lifecycle

The caller owns source and output directories. Generation writes a complete
manifest and derived files for one profile; it does not mutate actor runtime
state. The schema lock is the durable identity boundary between projections.

## Failure, Concurrency, and Constraints

Generation reports invalid declarations, stale locks, and compiler capability
errors instead of producing placeholder sources. Projection must use the
selected SDK's target arguments and Embedded whole-module compilation rules.

## Verification and Change Impact

`Tests/ActorSystemGenerationTests` covers scanning, lock reconciliation,
portable codecs, source writing, and projections. Generator changes require
authoritative regeneration and both native and Embedded validation builds.
