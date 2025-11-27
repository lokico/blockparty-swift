import Foundation
import PackagePlugin

@main
struct BlockParty_Swift: BuildToolPlugin {
	/// Entry point for creating build commands for targets in Swift packages.
	func createBuildCommands(context: PluginContext, target: Target)
		async throws -> [Command]
	{
		let tool = try context.tool(named: "BlockPartyTool")
		return try createBuildCommands(
			for: context.package.directoryURL,
			in: context.pluginWorkDirectoryURL,
			with: tool.url
		)
	}
}

#if canImport(XcodeProjectPlugin)
	import XcodeProjectPlugin

	extension BlockParty_Swift: XcodeBuildToolPlugin {
		// Entry point for creating build commands for targets in Xcode projects.
		func createBuildCommands(
			context: XcodePluginContext,
			target: XcodeTarget
		) throws -> [Command] {
			let tool = try context.tool(named: "BlockPartyTool")
			return try createBuildCommands(
				for: context.xcodeProject.directoryURL,
				in: context.pluginWorkDirectoryURL,
				with: tool.url
			)
		}
	}

#endif

extension BlockParty_Swift {
	/// Shared function that returns a configured build command for building blocks.
	func createBuildCommands(
		for targetDirectory: URL,
		in pluginWorkDirectory: URL,
		with toolPath: URL
	) throws -> [Command] {
		let inputFiles = try collectInputFiles(at: targetDirectory)
		guard !inputFiles.isEmpty else {
			print("No blocks found under \(targetDirectory.path)")
			return []
		}

		// Create output directory in plugin work directory
		let outputDirectory = pluginWorkDirectory.appendingPathComponent(
			"build"
		)

		// Return a command that will run during the build to process all blocks
		return [
			.buildCommand(
				displayName: "Building BlockParty blocks",
				executable: toolPath,
				arguments: [
					targetDirectory.path,
					outputDirectory.path,
				],
				inputFiles: inputFiles,
				outputFiles: [
					outputDirectory.appendingPathComponent(
						"BlockParty-Generated.swift"
					)
				]
			)
		]
	}
}
