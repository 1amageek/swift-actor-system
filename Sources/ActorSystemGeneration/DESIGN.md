# ActorSystemGeneration

## Purpose and Scope

Generation owns source scanning, portable actor schema modeling, schema-lock
reconciliation, generated source writing, and native/Embedded projection. It
is the authority behind the `actor-system` generated host and client sources.
It accepts an authored typed application error when that error is portable and
exported in the actor schema.

Parent: [`swift-actor-system`](../../DESIGN.md). Children: none.

## Responsibilities and Boundaries

The module validates actor declarations and emits deterministic codecs,
registration, and proxy sources for a selected profile. It does not execute
actors, own transport state, or invent a new public error wrapper. Authored
local effects remain typed. Standard client declarations retain those effects
for compiler target identity, while their generated remote call path and
Embedded remote entry points retain an untyped system-error boundary.

## Related Designs

| Design | Relationship | Contract Used | Summary | Cautions |
| --- | --- | --- | --- | --- |
| [`../../DESIGN.md`](../../DESIGN.md) | parent | schema and projection invariants | Package context | Generated artifacts are derived, not handwritten |
| [`../ActorSystemBuildSupport/DESIGN.md`](../ActorSystemBuildSupport/DESIGN.md) | used by | compiler target and fingerprint | Build environment input | Compiler and SDK must be paired |
| [`../ActorSystemEmbedded/DESIGN.md`](../ActorSystemEmbedded/DESIGN.md) | used by | Embedded registration/invocation | Generated runtime consumer | Verify target-level behavior, not syntax only |

## Architecture

```text
Swift actor source -> scanner/portability validation -> schema lock
                                      |
                             source writer/projector
                                      |
             authored typed declaration -> target projection
                         |                    |
                  typed local call      untyped remote call boundary
                                      |
                         native / Embedded host + client
```

## Contracts and Invariants

- A generated file is accepted only when its schema lock and toolchain
  fingerprint match the request.
- Generation is deterministic for the same sources, profile, lock, and
  compiler environment.
- An authored `throws(ErrorType)` is accepted when `ErrorType` passes the same
  portable-value validation as method arguments and results. The exact effect
  clause remains in the source model and schema lock, so method identity and
  schema reconciliation continue to distinguish typed and untyped methods.
- Native/local generated dispatch preserves the authored typed signature.
  Standard client declarations also retain the authored effect so Swift's
  compiler target identity remains aligned with the source; the compiler's
  remote call path is still an untyped system-error boundary. Embedded remote
  entry points explicitly expose untyped `throws` for the same reason.
- Embedded host dispatch catches only the authored typed application error and
  encodes it as the existing `ActorApplicationFailure` at the explicit codec
  boundary. The generated `ActorGeneratedCodec<ErrorType>` specialization is
  explicit so the existing `EmbeddedActorErrorCodec` receives the declared
  error codec. System and cancellation failures pass through as untyped system
  failures; no new public wrapper or Core algorithm is introduced.
- Unsupported effects or portable types remain explicit generation failures;
  a non-portable typed error is rejected as a portable type failure.
- Associated-value enum codecs bind each decoded payload in the generated
  switch arm.

## Runtime Flows

```text
scan -> validate portable values/effects -> reconcile lock -> emit manifest/sources
project -> verify lock/fingerprint -> emit target-specific local/remote files
```

## State, Ownership, and Lifecycle

The caller owns source and output directories. Generation writes a complete
manifest and derived files for one profile; it does not mutate actor runtime
state. The schema lock is the durable identity boundary between projections.

## Failure, Concurrency, and Constraints

Generation reports invalid declarations, stale locks, non-portable typed error
types, and compiler capability errors instead of producing placeholder
sources. Projection must use the selected SDK's target arguments and Embedded
whole-module compilation rules.

## Verification and Change Impact

`Tests/ActorSystemGenerationTests` covers scanning, lock reconciliation,
portable codecs, source writing, and projections. Generator changes require
authoritative regeneration and both native and Embedded validation builds.
