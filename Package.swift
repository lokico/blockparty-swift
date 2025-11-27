// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "BlockParty-Swift",
	platforms: [
		.macOS(.v26)
	],
	products: [
		// Products can be used to vend plugins, making them visible to other packages.
		.plugin(
			name: "BlockParty-Swift",
			targets: ["BlockParty-Swift"]
		),
		.library(
			name: "BlockParty",
			targets: ["BlockParty"]
		),
	],
	targets: [
		// Targets are the basic building blocks of a package, defining a module or a test suite.
		// Targets can depend on other targets in this package and products from dependencies.
		.plugin(
			name: "BlockParty-Swift",
			capability: .buildTool()
		),
		.executableTarget(
			name: "BlockPartyTool"
		),
		.target(
			name: "BlockParty"
		),
	]
)
