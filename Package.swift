// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "SkillSwitch",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "SkillSwitchCore",
            path: "Sources/SkillSwitchCore"
        ),
        .executableTarget(
            name: "SkillSwitch",
            dependencies: ["SkillSwitchCore"],
            path: "Sources/SkillSwitch"
        ),
        .testTarget(
            name: "SkillSwitchTests",
            dependencies: ["SkillSwitchCore"],
            path: "Tests/SkillSwitchTests"
        )
    ]
)
