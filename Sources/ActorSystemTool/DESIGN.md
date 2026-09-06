# ActorSystemTool

## Purpose and Scope

The `actor-system` executable is the command-line composition root for schema
generation, source generation, and target projection. It is a thin boundary
over ActorSystemBuildSupport and ActorSystemGeneration.

Parent: [`swift-actor-system`](../../DESIGN.md). Children: none.

## Responsibilities and Boundaries

The tool parses command options, constructs generation requests, and reports
invalid usage or generation failures. It does not own actor runtime state,
transport I/O, or a second generation algorithm.

## Related Designs

| Design | Relationship | Contract Used | Summary | Cautions |
| --- | --- | --- | --- | --- |
| [`../../DESIGN.md`](../../DESIGN.md) | parent | package generation contract | Package context | CLI output is derived from library contracts |
| [`../ActorSystemBuildSupport/DESIGN.md`](../ActorSystemBuildSupport/DESIGN.md) | depends on | compiler environment resolution | Build inputs | Preserve explicit target arguments |
| [`../ActorSystemGeneration/DESIGN.md`](../ActorSystemGeneration/DESIGN.md) | delegates to | schema and projection APIs | Generation authority | Do not handwrite generated sources |

## Architecture

```text
command line -> option parser -> BuildSupport -> Generation -> output files
```

## Contracts and Invariants

- `generate`, `project`, and `schema` operations require their documented
  options and fail explicitly when an option is missing or unknown.
- All generated output is produced by the Generation module and its manifest
  contract.
- The selected compiler and target arguments are passed through unchanged to
  BuildSupport and Generation.

## Runtime Flows

```text
parse command -> validate options -> invoke library -> return nonzero on error
```

## State, Ownership, and Lifecycle

The executable owns only parsed arguments and request values. Generation owns
the output write for the duration of the command; no persistent actor runtime
or background task is started by the CLI.

## Failure, Concurrency, and Constraints

Usage, target, lock, and generation failures propagate as process failures;
there is no placeholder output on error. The tool is synchronous at its
boundary and delegates all target capability decisions to BuildSupport.

## Verification and Change Impact

`Tests/ActorSystemBuildSupportTests` and `Tests/ActorSystemGenerationTests`
exercise the delegated contracts. Validation commands invoke the built tool to
produce the checked-in Embedded host/client sources.
