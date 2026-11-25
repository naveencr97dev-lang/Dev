// swift-tools-version:5.9
// Guide content + logic only (no UI), so `swift test` runs on Linux.
import PackageDescription

let package = Package(
    name: "ScoreBook",
    targets: [
        .target(name: "ScoreBookCore", path: "Sources/Core"),
        .testTarget(name: "CoreTests", dependencies: ["ScoreBookCore"], path: "Tests/CoreTests"),
    ]
)
