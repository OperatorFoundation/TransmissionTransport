// swift-tools-version:5.5
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
        .package(url: "https://github.com/OperatorFoundation/Chord.git", from: "0.0.15"),
        .package(url: "https://github.com/OperatorFoundation/Datable.git", from: "3.1.1"),
        .package(url: "https://github.com/OperatorFoundation/Transport.git", from: "2.3.9"),
        .package(url: "https://github.com/OperatorFoundation/Transmission.git", from: "1.2.0"),
        .package(url: "https://github.com/OperatorFoundation/Net.git", from: "0.0.1")
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
            "Net",
			.product(name: "Transmission", package: "Transmission"),
		]
	),
        .testTarget(
            name: "TransmissionTransportTests",
            dependencies: ["TransmissionTransport"]),
    ],
    swiftLanguageVersions: [.v5]
)
