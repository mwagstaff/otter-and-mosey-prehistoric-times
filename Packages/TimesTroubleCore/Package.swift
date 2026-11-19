// swift-tools-version: 6.0
import PackageDescription

// Platform-neutral game logic: question generation, adaptive difficulty,
// progression rules and save data. Foundation only, so it can be ported
// (or shared via its JSON content) with web and Android clients.
let package = Package(
    name: "TimesTroubleCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "TimesTroubleCore", targets: ["TimesTroubleCore"])
    ],
    targets: [
        .target(
            name: "TimesTroubleCore",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "TimesTroubleCoreTests",
            dependencies: ["TimesTroubleCore"]
        ),
    ]
)
