// swift-tools-version:5.9
import PackageDescription

let package = Package(
  name: "LegoLemmings",
  platforms: [.macOS(.v12)],
  targets: [
    .executableTarget(
      name: "LegoLemmings",
      path: "Sources/LegoLemmings"
    ),
    // Generates the themed levels in ../assets. Dev tool, not part of the game.
    .executableTarget(
      name: "LevelGen",
      path: "Sources/LevelGen"
    )
  ]
)
