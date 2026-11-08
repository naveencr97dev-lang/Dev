// swift-tools-version:5.9
// Lets the game engine (Foundation only) be built and unit-tested without Xcode:
//   cd ios && swift test
// The iOS app itself is generated from project.yml by XcodeGen.
import PackageDescription

let package = Package(
    name: "AuctionEngine",
    platforms: [.macOS(.v13), .iOS(.v16)],
    targets: [
        .target(name: "AuctionEngine", path: "Sources/Engine"),
        .testTarget(name: "EngineTests", dependencies: ["AuctionEngine"], path: "Tests/EngineTests"),
    ]
)
