// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DiagnosticKit",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "DiagnosticKit",
            targets: ["DiagnosticKit"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "DiagnosticKit",
            dependencies: [],
            path: "Sources"
        )
    ]
)
