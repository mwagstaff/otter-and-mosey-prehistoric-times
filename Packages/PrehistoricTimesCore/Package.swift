// swift-tools-version: 6.0
import PackageDescription

// Platform-neutral game logic: question generation, adaptive difficulty,
// progression rules and save data. Foundation only, so it can be ported
// (or shared via its JSON content) with web and Android clients.
let package = Package(
    name: "PrehistoricTimesCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PrehistoricTimesCore", targets: ["PrehistoricTimesCore"])
    ],
    targets: [
        .target(
            name: "PrehistoricTimesCore",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "PrehistoricTimesCoreTests",
            dependencies: ["PrehistoricTimesCore"]
        ),
    ]
)
