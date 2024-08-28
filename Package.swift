// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CameraKit",
    platforms: [.iOS(.v16)],
    products: [
        .library(
            name: "CameraKit",
            targets: ["CameraKit"]),
    ],
    dependencies: [
      .package(url: "https://github.com/mattmassicotte/Queue", from: "0.1.4"),
    ],
    targets: [
        .target(name: "CameraKit", dependencies: [.product(name: "Queue", package: "Queue")]),
    ]
)
