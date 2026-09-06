# ActorSystemBuildSupport

## Purpose and Scope

BuildSupport resolves compiler target environments and records the compiler
fingerprint consumed by source generation. It is the `ActorSystemBuildSupport`
module and the library used by the command-line tool.

Parent: [`swift-actor-system`](../../DESIGN.md). Children: none.

## Responsibilities and Boundaries

The module translates explicit compiler arguments into a target environment
and verifies toolchain identity. It does not compile actor runtime code,
choose deployment policy, or replace the generator's portability validators.

## Related Designs

| Design | Relationship | Contract Used | Summary | Cautions |
| --- | --- | --- | --- | --- |
| [`../../DESIGN.md`](../../DESIGN.md) | parent | deterministic generation invariant | Package context | Do not infer SDK capability from host platform |
| [`../ActorSystemGeneration/DESIGN.md`](../ActorSystemGeneration/DESIGN.md) | used by | target and fingerprint inputs | Generation authority | Mismatched fingerprints reject projection |
| [`../ActorSystemTool/DESIGN.md`](../ActorSystemTool/DESIGN.md) | used by | CLI request construction | Command entry point | Preserve explicit argument failures |

## Architecture

```text
swiftc + compiler arguments -> target extractor/resolver
                                      |
                             target environment + fingerprint
                                      |
                                ActorSystemGeneration
```

## Contracts and Invariants

- Target triple, SDK, Embedded feature, and compiler fingerprint describe one
  build contract.
- Unrecognized or contradictory compiler arguments are reported as errors.
- The fingerprint is stable for a fixed compiler executable and is compared
  before projecting a previously locked schema.

## Runtime Flows

```text
CLI request -> resolve compiler target -> compute fingerprint -> generation
```

## State, Ownership, and Lifecycle

BuildSupport retains no runtime actor state. It returns value descriptions of
the requested compiler environment; callers own the subsequent compilation and
output lifecycle.

## Failure, Concurrency, and Constraints

Resolution must not silently fall back to a host target or mismatched SDK.
Inputs are read-only compiler metadata and no asynchronous operation occurs in
the resolver's synchronous state path.

## Verification and Change Impact

`Tests/ActorSystemBuildSupportTests` covers target extraction and environment
resolution. Changes require the generation tests and pinned native/Embedded
projection commands to be rerun.
