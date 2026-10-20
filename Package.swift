// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NutriPilot",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "NutriPilotCore",
            targets: ["NutriPilotCore"]
        ),
        .library(
            name: "NutriPilotApp",
            targets: ["NutriPilotApp"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "NutriPilotCore",
            dependencies: [],
            path: "Sources/NutriPilotCore"
        ),
        .target(
            name: "NutriPilotApp",
            dependencies: ["NutriPilotCore"],
            path: "Sources/NutriPilotApp"
        ),
        .testTarget(
            name: "NutriPilotTests",
            dependencies: ["NutriPilotCore"],
            path: "Tests/NutriPilotTests"
        ),
    ]
)
