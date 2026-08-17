// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CodexUsageFloat",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "AgentUsageCore", targets: ["AgentUsageCore"]),
        .executable(name: "CodexUsageFloat", targets: ["CodexUsageFloat"])
    ],
    targets: [
        .target(name: "AgentUsageCore"),
        .executableTarget(
            name: "CodexUsageFloat",
            dependencies: ["AgentUsageCore"]
        ),
        .testTarget(
            name: "AgentUsageCoreTests",
            dependencies: ["AgentUsageCore"]
        )
    ]
)
