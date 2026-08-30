// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SeguraMinhasNotas",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "SeguraMinhasNotas", targets: ["SeguraMinhasNotas"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.2")
    ],
    targets: [
        .executableTarget(
            name: "SeguraMinhasNotas",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/SeguraMinhasNotas",
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-strict-concurrency=minimal"])
            ],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])
            ]
        )
    ],
    swiftLanguageModes: [.v5]
)
