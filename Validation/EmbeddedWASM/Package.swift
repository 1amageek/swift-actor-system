// swift-tools-version: 6.4

import PackageDescription
import Foundation

var embeddedLinkerSettings: [LinkerSetting] = []
if let unicodeArchive = ProcessInfo.processInfo.environment["ACTOR_SYSTEM_UNICODE_ARCHIVE"] {
    embeddedLinkerSettings = [.unsafeFlags(["-Xlinker", unicodeArchive], .when(platforms: [.wasi]))]
}

let package = Package(
    name: "EmbeddedActorValidation",
    platforms: [
        .macOS(.v15),
    ],
    dependencies: [
        .package(
            url: "https://github.com/1amageek/swift-actor-system.git",
            revision: "308c56105d3203045b8633e77d983153eb3bd72c"
        ),
    ],
    targets: [
        .executableTarget(
            name: "CounterFixture",
            dependencies: [
                .product(name: "ActorSystemCore", package: "swift-actor-system"),
                .product(name: "ActorSystemDistributed", package: "swift-actor-system"),
                .product(name: "ActorSystemTestSupport", package: "swift-actor-system"),
            ],
            path: ".",
            exclude: [
                "README.md", "ActorSchema.lock", "run-node.mjs",
                "Sources/EmbeddedActorHost", "Sources/EmbeddedActorClient",
                "Sources/EmbeddedActorValidation",
            ],
            sources: ["Input", "Sources/NativeActorValidation"]
        ),
        .target(
            name: "EmbeddedActorHost",
            dependencies: [
                .product(name: "ActorSystemCore", package: "swift-actor-system"),
                .product(name: "ActorSystemEmbedded", package: "swift-actor-system"),
            ],
            path: "Sources/EmbeddedActorHost",
            exclude: ["ActorGeneratedManifest.json"]
        ),
        .target(
            name: "EmbeddedActorClient",
            dependencies: [
                .product(name: "ActorSystemCore", package: "swift-actor-system"),
                .product(name: "ActorSystemEmbedded", package: "swift-actor-system"),
            ],
            path: "Sources/EmbeddedActorClient",
            exclude: ["ActorGeneratedManifest.json"]
        ),
        .executableTarget(
            name: "EmbeddedActorValidation",
            dependencies: [
                "EmbeddedActorHost",
                "EmbeddedActorClient",
                .product(name: "ActorSystemCore", package: "swift-actor-system"),
                .product(name: "ActorSystemEmbedded", package: "swift-actor-system"),
                .product(name: "ActorSystemTestSupport", package: "swift-actor-system"),
            ],
            path: "Sources/EmbeddedActorValidation",
            linkerSettings: embeddedLinkerSettings
        ),
    ]
)
