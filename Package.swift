// swift-tools-version:5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TransmissionTransport",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "TransmissionTransport",
            targets: ["TransmissionTransport"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/OperatorFoundation/Chord", from: "0.1.4"),
        .package(url: "https://github.com/OperatorFoundation/Datable", from: "4.0.1"),
        .package(url: "https://github.com/OperatorFoundation/Net", from: "0.0.10"),
        .package(url: "https://github.com/OperatorFoundation/Straw", from: "1.0.1"),
        .package(url: "https://github.com/OperatorFoundation/Transport", from: "2.3.13"),
        .package(url: "https://github.com/OperatorFoundation/Transmission", from: "1.2.11"),
        .package(url: "https://github.com/OperatorFoundation/SwiftHexTools", from: "1.2.6"),
        .package(url: "https://github.com/apple/swift-log", from: "1.5.3"),
    ],
    targets: [
        .target(
		name: "TransmissionTransport",
		dependencies:
		[
			"Chord",
			"Datable",
            "Straw",
			"Transport",
            "Net",
			"Transmission",
            "SwiftHexTools",
            .product(name: "Logging", package: "swift-log"),
		]
	),
        .testTarget(
            name: "TransmissionTransportTests",
            dependencies: ["TransmissionTransport"]),
    ],
    swiftLanguageVersions: [.v5]
)
