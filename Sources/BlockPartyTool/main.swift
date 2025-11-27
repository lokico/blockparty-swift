import Foundation

struct BlockMetadata: Decodable {
	let name: String
	let path: String
	let propDefinitions: [PropDefinition]
	let title: String?
	let description: String?
	let categories: [String]?
}

struct PropDefinition: Decodable {
	let name: String
	let type: String
	let required: Bool
}

struct BuildOutput: Decodable {
	let blocks: [BlockMetadata]
	let importmap: [String: String]
}

/// Main entry point for the BlockParty build tool
@main
struct BlockPartyTool {
	static func main() async {
		let arguments = CommandLine.arguments

		guard arguments.count >= 3 else {
			print("Usage: blockparty-tool <package-dir> <output-dir>")
			exit(1)
		}

		let packageDir = arguments[1]
		let outputDir = arguments[2]

		print("🏗️  Building Blocks...")
		print("📂 Package: \(packageDir)")
		print("📦 Output: \(outputDir)\n")

		do {
			try await buildBlocks(packageDir: packageDir, outputDir: outputDir)
		} catch {
			print("❌ Build failed: \(error)")
			exit(1)
		}
	}

	static func buildBlocks(packageDir: String, outputDir: String) async throws
	{
		let packageURL = URL(fileURLWithPath: packageDir)
		let outputURL = URL(fileURLWithPath: outputDir)

		// Run npx blockparty command
		let process = Process()
		process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
		let args = [
			"npx", "-y", "blockparty", "build", "--individually", packageDir,
			outputDir,
		]
		process.arguments = args
		process.currentDirectoryURL = packageURL

		let outputPipe = Pipe()
		let errorPipe = Pipe()
		process.standardOutput = outputPipe
		process.standardError = errorPipe

		print("🚀 Running: \(args.joined(separator: " "))")

		try process.run()

		// Read output
		let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
		if let output = String(data: outputData, encoding: .utf8),
			!output.isEmpty
		{
			print(output)
		}

		// Read errors
		let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
		if let errorOutput = String(data: errorData, encoding: .utf8),
			!errorOutput.isEmpty
		{
			print(errorOutput)
		}

		process.waitUntilExit()

		guard process.terminationStatus == 0 else {
			throw BuildError.processFailure(exitCode: process.terminationStatus)
		}

		print("\n📋 Reading build output from index.json...")
		let indexPath = outputURL.appendingPathComponent("index.json")
		let indexData = try Data(contentsOf: indexPath)
		let buildOutput = try JSONDecoder().decode(
			BuildOutput.self,
			from: indexData
		)

		// FIXME: Create BlockParty-Generated.swift file with a struct for each Block that
		//  conforms to the Block protocol.

		print("\n✅ Build complete! Output in \(outputDir)/")
	}
}

enum BuildError: Error, CustomStringConvertible {
	case processFailure(exitCode: Int32)
	case missingIndexFile(path: String)

	var description: String {
		switch self {
		case .processFailure(let exitCode):
			return "npx blockparty process failed with exit code \(exitCode)"
		case .missingIndexFile(let path):
			return "Expected index.json not found at \(path)"
		}
	}
}
