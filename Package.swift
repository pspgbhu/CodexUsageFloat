// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AgentUsageFloat",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "AgentUsageCore", targets: ["AgentUsageCore"]),
        .executable(name: "AgentUsageFloat", targets: ["AgentUsageFloat"])
    ],
    targets: [
        .target(name: "AgentUsageCore"),
        .executableTarget(
            name: "AgentUsageFloat",
            dependencies: ["AgentUsageCore"]
        ),
        .testTarget(
            name: "AgentUsageCoreTests",
            dependencies: ["AgentUsageCore"]
        )
    ]
)
