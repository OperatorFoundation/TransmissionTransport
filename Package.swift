// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TransmissionTransport",
    platforms: [
      .macOS(.v10_15)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "TransmissionTransport",
            targets: ["TransmissionTransport"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/OperatorFoundation/Chord.git", from: "0.0.10"),
        .package(url: "https://github.com/OperatorFoundation/Datable.git", from: "3.0.4"),
        .package(url: "https://github.com/OperatorFoundation/Transport.git", from: "2.3.0"),
        .package(url: "https://github.com/OperatorFoundation/Transmission.git", from: "0.2.0"),
        .package(url: "https://github.com/OperatorFoundation/TransmissionLinux.git", from: "0.3.1"),
        .package(url: "https://github.com/OperatorFoundation/NetworkLinux.git", from: "0.3.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
		name: "TransmissionTransport",
		dependencies:
		[
			"Chord",
			"Datable",
			"Transport",
			.product(name: "NetworkLinux", package: "NetworkLinux", condition: .when(platforms: [.linux])),
			.product(name: "Transmission", package: "Transmission", condition: .when(platforms: [.macOS])),
			.product(name: "TransmissionLinux", package: "TransmissionLinux", condition: .when(platforms: [.linux])),
		]
	),
        .testTarget(
            name: "TransmissionTransportTests",
            dependencies: ["TransmissionTransport"]),
    ],
    swiftLanguageVersions: [.v5]
)