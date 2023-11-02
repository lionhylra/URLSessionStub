// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "URLSessionStub",
    platforms: [.macOS(.v13), .iOS(.v15)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "URLSessionStub",
            targets: ["URLSessionStub"]),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "URLSessionStub"),
        .testTarget(
            name: "URLSessionStubTests",
            dependencies: ["URLSessionStub"]),
    ]
)

let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("BareSlashRegexLiterals"),
    .enableUpcomingFeature("StrictConcurrency"),
    .unsafeFlags(["-enable-actor-data-race-checks"],
        .when(configuration: .debug)),
]

for target in package.targets {
    target.swiftSettings = target.swiftSettings ?? []
    target.swiftSettings?.append(contentsOf: swiftSettings)
}
