// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "OggOpus",
    platforms: [.iOS(.v15)],
    products: [.library(name: "OggOpus", targets: ["OggOpus"])],
    dependencies: [
        .package(url: "https://github.com/vizoss/ogg-swift.git", exact: "0.8.3"),
        .package(url: "https://github.com/vizoss/opus-swift.git", exact: "0.8.3"),
    ],
    targets: [
        .target(name: "OggOpus", dependencies: [
            .product(name: "YbridOgg", package: "ogg-swift"),
            .product(name: "YbridOpus", package: "opus-swift"),
        ], path: "Sources/OggOpus")
    ]
)
