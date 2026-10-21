// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "swift-rfc-3501-coder",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
        .tvOS(.v27),
        .watchOS(.v27),
        .visionOS(.v27),
    ],
    products: [
        .library(
            name: "RFC 3501 Coder",
            targets: ["RFC 3501 Coder"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/swift-atoms/swift-byte.git", branch: "main"),
        .package(url: "https://github.com/swift-ietf/swift-rfc-3501.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "RFC 3501 Coder",
            dependencies: [
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "RFC 3501", package: "swift-rfc-3501"),
            ]
        ),
        .testTarget(
            name: "RFC 3501 Coder Tests",
            dependencies: [
                .target(name: "RFC 3501 Coder"),
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "RFC 3501", package: "swift-rfc-3501"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    target.swiftSettings =
        (target.swiftSettings ?? []) + [
            .strictMemorySafety(),
            .enableUpcomingFeature("ExistentialAny"),
            .enableUpcomingFeature("InternalImportsByDefault"),
            .enableUpcomingFeature("MemberImportVisibility"),
            .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
            .enableUpcomingFeature("InferIsolatedConformances"),
            .enableExperimentalFeature("Lifetimes"),
            .treatAllWarnings(as: .error),
        ]
}
