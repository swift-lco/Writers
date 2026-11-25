// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Writers",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Writers",
            targets: ["Writers"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-lco/IO.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Difference.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Position.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Readers.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Path.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Errors.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "Writers",
            dependencies: [
                .product(name: "IO", package: "IO"),
                .product(name: "Difference", package: "Difference"),
                .product(name: "Position", package: "Position"),
                .product(name: "Readers", package: "Readers"),
                .product(name: "Path", package: "Path"),
                .product(name: "Errors", package: "Errors"),
            ],
        ),
    ]
)
