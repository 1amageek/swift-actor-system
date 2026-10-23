# Embedded WASM validation

This fixture is the target-level validation for the generated Embedded actor
projection. `Input/Counter.swift` and `Input/TypedCounter.swift` are authored
distributed actors. The original Counter contract remains unchanged; the
separate TypedCounter exercises authored `throws(CounterError)`. The
checked-in host and client sources under `Sources/EmbeddedActorHost` and
`Sources/EmbeddedActorClient` were produced by `ActorSystemGeneration` from the
same `ActorSchema.lock`; they are not handwritten proxy implementations.

| Boundary | Required behavior |
| --- | --- |
| Authored method / Embedded private local method | Retain `throws(CounterError)` |
| Native compiler remote thunk / generated Embedded remote method | Untyped `throws`, preserving application, cancellation, and system errors |
| Application failure | Exact generated `CounterError.rejected(-42)` across the transport |
| Pre-cancelled call / post-shutdown call | `ActorSystemError.cancelled` / `.shuttingDown`, not a business error |

The Native executable uses the same authored actors and generated native
bootstrap. Its module name is `CounterFixture`, matching the compiler aliases
in the lock. Select the executable product explicitly when cross-compiling;
the Native compiler's `Distributed` module is not an Embedded dependency.

## Fixed toolchain

| Component | Value |
| --- | --- |
| Swift compiler | `swift-6.4.0-RELEASE` |
| Host toolchain | `org.swift.640202609131a` (release `swift-6.4-RELEASE`) |
| Embedded SDK | `swift-6.4.0-RELEASE_wasm-embedded` |
| Target | `wasm32-unknown-wasip1` |
| Runtime | Node.js WASI (`node`, or `NODE` override) |

The Embedded SDK's `libswiftUnicodeDataTables.a` is required by the actor
runtime's `String` paths. Resolve it from the matching SDK configuration; do
not use a library from another toolchain.

## Generate and build

The validation package depends on the public `swift-actor-system` 0.3.0
release. Published-release verification requires no local dependency path or
edit override. During development, SwiftPM edits must use the same scratch
path as the corresponding build and must be removed before tagging.

Run the generation and build commands below from the repository root. The
tool is built first with the pinned release toolchain, and the SDK root and
Swift resources are derived from that toolchain's SDK configuration. The
first generation command is authoritative native generation; the following
two commands are lock-checked Embedded projections. The generated output
directories are copied into the two SwiftPM targets and the generated Swift
files are checked in for the validation package.

```sh
set -eu
SWIFT="${SWIFT:-$(xcrun --find swift)}"
SWIFTC="${SWIFTC:-$(xcrun --find swiftc)}"
"$SWIFT" --version
"$SWIFTC" --version
"$SWIFT" sdk list
# Both compilers must report the Swift 6.4 release; SDK IDs below must match.
TIMEOUT="$PWD/scripts/swift-test-timeout.sh"
VALIDATION="$PWD/Validation/EmbeddedWASM"
SCRATCH="$VALIDATION/.build-embedded"
CONFIG="$VALIDATION/.swiftpm/config"
TARGET=wasm32-unknown-wasip1
EMBEDDED_SDK_ID=swift-6.4.0-RELEASE_wasm-embedded
WASM_SDK_ID=swift-6.4.0-RELEASE_wasm
NODE="${NODE:-$(command -v node)}"
MACOS_SDK="${MACOS_SDK:-$(xcrun --sdk macosx --show-sdk-path)}"

EMBEDDED_CONFIG="$("$SWIFT" sdk configure --show-configuration \
  "$EMBEDDED_SDK_ID" "$TARGET")"
SDK_ROOT="${SDK_ROOT:-$(printf '%s\n' "$EMBEDDED_CONFIG" \
  | sed -n 's/^sdkRootPath: //p')}"
RESOURCES="${RESOURCES:-$(printf '%s\n' "$EMBEDDED_CONFIG" \
  | sed -n 's/^swiftResourcesPath: //p')}"
UNICODE_ARCHIVE="${UNICODE_ARCHIVE:-$RESOURCES/embedded/$TARGET/libswiftUnicodeDataTables.a}"
test -x "$SWIFT"
test -x "$SWIFTC"
test -x "$NODE"
test -d "$SDK_ROOT"
test -d "$RESOURCES"
test -f "$UNICODE_ARCHIVE"

# Build the generation tool before resolving its output path.
"$TIMEOUT" 600 -- "$SWIFT" build --build-path "$PWD/.build" --jobs 2
BIN="$("$SWIFT" build --build-path "$PWD/.build" --show-bin-path)"
ACTOR_SYSTEM="$BIN/actor-system"
test -x "$ACTOR_SYSTEM"

"$TIMEOUT" 120 -- "$ACTOR_SYSTEM" generate \
  --module CounterFixture --package embedded-actor-validation --profile nativeHost \
  --source "$VALIDATION/Input/Counter.swift" --source-root "$VALIDATION/Input" \
  --source "$VALIDATION/Input/TypedCounter.swift" \
  --lock "$VALIDATION/ActorSchema.lock" --output "$VALIDATION/.generated/native" \
  --swiftc "$SWIFTC" --compiler-arg -sdk --compiler-arg "$MACOS_SDK" \
  --compiler-arg -I --compiler-arg "$BIN"

"$TIMEOUT" 120 -- "$ACTOR_SYSTEM" project \
  --module CounterFixture --package embedded-actor-validation --profile embeddedHost \
  --available-module ActorSystemCore \
  --source "$VALIDATION/Input/Counter.swift" --source-root "$VALIDATION/Input" \
  --source "$VALIDATION/Input/TypedCounter.swift" \
  --lock "$VALIDATION/ActorSchema.lock" --output "$VALIDATION/.generated/host" \
  --swiftc "$SWIFTC" --compiler-arg -sdk --compiler-arg "$SDK_ROOT" \
  --compiler-arg -sysroot --compiler-arg "$SDK_ROOT" \
  --compiler-arg -resource-dir --compiler-arg "$RESOURCES" \
  --compiler-arg -target --compiler-arg "$TARGET" \
  --compiler-arg -enable-experimental-feature --compiler-arg Embedded \
  --compiler-arg -static-stdlib

"$TIMEOUT" 120 -- "$ACTOR_SYSTEM" project \
  --module CounterFixture --package embedded-actor-validation --profile embeddedClient \
  --source "$VALIDATION/Input/Counter.swift" --source-root "$VALIDATION/Input" \
  --source "$VALIDATION/Input/TypedCounter.swift" \
  --lock "$VALIDATION/ActorSchema.lock" --output "$VALIDATION/.generated/client" \
  --swiftc "$SWIFTC" --compiler-arg -sdk --compiler-arg "$SDK_ROOT" \
  --compiler-arg -sysroot --compiler-arg "$SDK_ROOT" \
  --compiler-arg -resource-dir --compiler-arg "$RESOURCES" \
  --compiler-arg -target --compiler-arg "$TARGET" \
  --compiler-arg -enable-experimental-feature --compiler-arg Embedded \
  --compiler-arg -static-stdlib

cp -R "$VALIDATION/.generated/host/." "$VALIDATION/Sources/EmbeddedActorHost/"
cp -R "$VALIDATION/.generated/client/." "$VALIDATION/Sources/EmbeddedActorClient/"
cp "$VALIDATION/.generated/native/ActorSchema.generated.swift" \
  "$VALIDATION/.generated/native/ActorCodecs.generated.swift" \
  "$VALIDATION/.generated/native/Native/ActorRegistrations.generated.swift" \
  "$VALIDATION/Sources/NativeActorValidation/"

"$TIMEOUT" 300 -- "$SWIFT" build --package-path "$VALIDATION" \
  --product CounterFixture --jobs 2
NATIVE_BIN="$("$SWIFT" build --package-path "$VALIDATION" --show-bin-path)"
"$TIMEOUT" 120 -- "$NATIVE_BIN/CounterFixture"

"$TIMEOUT" 300 -- env \
  ACTOR_SYSTEM_UNICODE_ARCHIVE="$UNICODE_ARCHIVE" \
  "$SWIFT" build --package-path "$VALIDATION" \
    --config-path "$CONFIG" --scratch-path "$SCRATCH" \
    --swift-sdk "$EMBEDDED_SDK_ID" --product EmbeddedActorValidation --jobs 2
"$TIMEOUT" 120 -- "$NODE" "$VALIDATION/run-node.mjs" \
  "$SCRATCH/out/Products/Debug-webassembly-wasm32/EmbeddedActorValidation.wasm"

"$TIMEOUT" 300 -- "$SWIFT" build --package-path "$VALIDATION" \
  --config-path "$CONFIG" --scratch-path "$VALIDATION/.build-wasm" \
  --swift-sdk "$WASM_SDK_ID" --product EmbeddedActorValidation --jobs 2
"$TIMEOUT" 120 -- "$NODE" "$VALIDATION/run-node.mjs" \
  "$VALIDATION/.build-wasm/out/Products/Debug-webassembly-wasm32/EmbeddedActorValidation.wasm"
```

`ActorGeneratedManifest.json` and `.actor-system-generated-files.json` are
generated locally by the commands above but are intentionally not checked in:
the manifest records the local source root and the ledger hashes that
machine-specific file. The checked-in generated Swift sources, authored input,
and schema lock are the portable fixture inputs.

The Embedded run prints `clock=unavailable`; the standard WASM run prints
`clock=native`. Both runs print the remaining validation markers on success:

```text
clock=unavailable
scoped-call-options=initializer:1s, scoped:defaults
generated-typed-failure=rejected(-42) success=42
generated-typed-cancellation=cancelled
generated-untyped-failure=remoteFailure
typed-wire-failure=rejected(-1)
binary-frames=client:8,server:8
generated-typed-system-failure=shuttingDown
shutdown=terminal post-shutdown=shuttingDown
```

The original Counter's generated client method has no authored error type,
so its application failure maps to `remoteFailure` when no error codec is
supplied. The same generated host/result path preserves the wire
`ActorApplicationFailure`; the fixture then calls `EmbeddedActorSystem.invoke`
with the generated `CounterError` codec to verify typed decoding at the
explicit application boundary. The added TypedCounter supplies its generated
error codec automatically while retaining an untyped remote wrapper. Its
success, exact business failure, cancellation, and shutdown checks therefore
exercise the generated method rather than a handwritten invocation. The
Native executable emits the corresponding `native-typed-*` markers through
the compiler-generated remote thunk and generated registration bootstrap.

The generated client also verifies that task-scoped `.defaults` overrides its
initializer timeout and that two simultaneously active task scopes produce
their distinct deadlines in real invocation frames. The server is started
inside a temporary scope; a later inbound interceptor calls a second generated
actor and verifies that it uses its own initializer timeout, not the expired
startup scope. Every actor system is explicitly shut down. These checks use
manual clocks and Node WASI; they do not establish Cloudflare page-host behavior.

## Release 0.3.0 evidence

Swift 6.4.0 release generation preserves all actor, method, value, field and
case IDs and schema fingerprints. Compiler target aliases are refreshed for
the release compiler. Generated Native, Standard WASM and Embedded WASM calls
must pass the success, typed failure, cancellation and terminal shutdown
checks above. New RawSpan integer reads execute through the real binary frame
adapter. Native focused tests additionally cover golden bytes, unaligned
slices, truncation, snapshot retention and storage release, including Address
Sanitizer validation. The Node WASI evidence does not establish browser,
Cloudflare-host or hardware-board behavior.
