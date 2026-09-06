# swift-actor-system

`swift-actor-system` is a transport-independent actor runtime for Swift
distributed actors, with source-generated portable codecs and projections for
native and Embedded Swift targets.

The 0.1.0 release provides the Core, Distributed, Embedded, Generation,
BuildSupport, Compatibility, and TestSupport modules plus the `actor-system`
generation tool. The package targets the
Swift 6.4 development snapshot pinned in `.swift-version`.

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
    .package(url: "https://github.com/1amageek/swift-actor-system.git", from: "0.1.0")
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
