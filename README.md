# swift-actor-system

`swift-actor-system` is a transport-independent actor runtime for Swift
distributed actors, with source-generated portable codecs and projections for
native and Embedded Swift targets.

The 0.3.0 release provides the Core, Distributed, Embedded, Generation,
BuildSupport, Compatibility, and TestSupport modules plus the `actor-system`
generation tool. The package targets the
Swift 6.4.0 release toolchain pinned in `.swift-version` and matching
WASM SDKs. The minimum macOS deployment target remains macOS 15.

## Architecture

```text
Generated actor source
        |
        v
ActorSystemEmbedded / ActorSystemDistributed
        |
        v
ActorSystemCore -- ActorRouter -- ActorTransport
        |
        +--> native transport implementations
        +--> portable LoopbackActorTransport in TestSupport
```

Core owns call identity, lifecycle, routing, frame validation, pending calls,
deadlines, cancellation, and typed failure propagation. A transport owns only
delivery and its incoming stream. Embedded projections use the same Core
state and `Synchronization.Mutex` contract as native targets; a platform
provides the actual timer and transport implementation.

## Add the package

```swift
dependencies: [
    .package(url: "https://github.com/1amageek/swift-actor-system.git", from: "0.3.0")
]
```

Use the product that owns the boundary you need:

| Product | Responsibility |
| --- | --- |
| `ActorSystemCore` | actor addresses, frames, routing, transport and lifecycle contracts |
| `ActorSystemDistributed` | native distributed-actor integration |
| `ActorSystemEmbedded` | Embedded Swift actor instances and generated invocation |
| `ActorSystemGeneration` | source scanning, schema locks, and generated projections |
| `ActorSystemBuildSupport` | build-plugin and command-line integration support |
| `ActorSystemCompatibility` | legacy gateway compatibility layer |
| `ActorSystemTestSupport` | deterministic clocks, static routing, and loopback transport |
| `actor-system` | schema, source, and target projection command-line tool |

## Generate actor projections

Author the distributed actor once, run `actor-system generate` for the
authoritative native schema, then run `actor-system project` for each target
profile. Commit `ActorSchema.lock`; generated output is owned by the manifest
written beside it.

```text
actor source + pinned swiftc
          |
          v
 actor-system generate  ---> ActorSchema.lock + native registration
          |
          +--> actor-system project --profile embeddedHost
          +--> actor-system project --profile embeddedClient
```

The `embeddedHost` and `embeddedClient` profiles replace the distributed actor
declaration with generated Embedded actors and generated portable codecs. The
portable contract accepts untyped `throws` and `throws(ErrorType)` when the
error type has a portable schema. Authored Native/local effects are retained;
remote calls remain untyped so transport, cancellation, and system failures
can propagate. Generated typed-error calls use the existing application codec
to preserve the concrete error and its payload across the transport.

## Verification

The checked-in [validation fixture](Validation/EmbeddedWASM/README.md) runs
the authored Native actor through Swift's actual remote thunk, and the
generated host/client through binary loopback on Standard and Embedded WASM.
Typed-error calls verify success, exact application errors, cancellation,
and post-shutdown system errors. The original untyped fixture separately
retains its `remoteFailure` mapping and explicit typed codec check. Embedded
also verifies that its default clock reports the unavailable capability.
The fixture documents the pinned toolchain, dependency revision, and commands.

## License

MIT. See [LICENSE](LICENSE).

## Swift 6.4 improvements in 0.3.0

Compiler output is captured in temporary files so large stdout/stderr streams
cannot deadlock generation. Public compiler and generation APIs remain
synchronous, with unchanged exit-status and diagnostic propagation.

`ActorByteBuffer.withRawSpan` provides a scoped, nonescaping borrow of its
readable range. Payload and frame integer reads use safe RawSpan loads after
length validation. Integer, Boolean, string and enum encoding writes directly
to the destination buffer while preserving wire version 1 and snapshot values.

The [codec benchmark](Validation/CodecBenchmark.swift) performs 20,000 payload
encode/decode roundtrips with 20 fields. On arm64 macOS 27 with Swift 6.4.0 and
`-O`, the median of five samples decreased from 68.43 ms to 42.95 ms (37.2%).
The checksums matched. This measures the codec workload, not network throughput.
Reproduce it from the package root:

```sh
scripts/swift-test-timeout.sh 180 -- xcrun swiftc \
  -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
  -O -whole-module-optimization -parse-as-library \
  -module-name ActorSystemCore -package-name swift_actor_system \
  -enable-upcoming-feature ApproachableConcurrency \
  Sources/ActorSystemCore/*.swift Validation/CodecBenchmark.swift \
  -o /tmp/actor-codec-benchmark
scripts/swift-test-timeout.sh 90 -- /tmp/actor-codec-benchmark
```
