// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "VitalsMac",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "VitalsMac", targets: ["VitalsMac"]),
        .library(name: "SensorKit", targets: ["SensorKit"]),
    ],
    targets: [
        .target(name: "CSMC", linkerSettings: [.linkedFramework("IOKit")]),
        .target(
            name: "SensorKit",
            dependencies: ["CSMC"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "VitalsMac",
            dependencies: ["SensorKit"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "SensorKitTests",
            dependencies: ["SensorKit"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
