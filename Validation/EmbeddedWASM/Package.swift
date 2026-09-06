// swift-tools-version: 6.4

import PackageDescription
import Foundation

var embeddedLinkerSettings: [LinkerSetting] = []
if let unicodeArchive = ProcessInfo.processInfo.environment["ACTOR_SYSTEM_UNICODE_ARCHIVE"] {
    embeddedLinkerSettings = [.unsafeFlags(["-Xlinker", unicodeArchive])]
}

let package = Package(
    name: "EmbeddedActorValidation",
    platforms: [
        .macOS(.v15),
    ],
    dependencies: [
        .package(
            url: "https://github.com/1amageek/swift-actor-system.git",
            exact: "0.1.0"
        ),
    ],
    targets: [
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
