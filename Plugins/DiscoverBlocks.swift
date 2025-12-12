// WARNING! This file should match the logic in discoverBlocks.ts in blockparty.
//  Keep any changes in sync with that file!!!

import Foundation

/// Metadata and information about a discovered block
struct BlockInfo {
	let name: String
	let path: URL
	let inputFiles: [URL]  // Build dependencies (index.ts/tsx, README.md, etc.)
	let outputFiles: [URL]  // Bundle resources
}

/// Discovers all blocks in the target path
/// - Parameter targetPath: The directory to search for blocks
/// - Returns: Array of discovered block information
func discoverBlocks(at targetPath: URL, into outputDirectory: URL) throws
	-> [BlockInfo]
{
	var blocks: [BlockInfo] = []

	// Try to get block info for the target path itself
	if let blockInfo = try getBlockInfo(at: targetPath, into: outputDirectory) {
		blocks.append(blockInfo)
		return blocks
	}

	// Recursively check subdirectories for blocks
	try discoverBlocksRecursive(
		at: targetPath,
		into: outputDirectory,
		blocks: &blocks
	)

	return blocks
}

/// Recursively discovers blocks in subdirectories
/// - Parameters:
///   - dirPath: The directory to search
///   - blocks: Array to accumulate discovered blocks
private func discoverBlocksRecursive(
	at dirPath: URL,
	into outputDirectory: URL,
	blocks: inout [BlockInfo]
)
	throws
{
	let fileManager = FileManager.default
	guard
		let entries = try? fileManager.contentsOfDirectory(
			at: dirPath,
			includingPropertiesForKeys: [.isDirectoryKey],
			options: [.skipsHiddenFiles]
		)
	else {
		return
	}

	for entry in entries {
		guard
			let resourceValues = try? entry.resourceValues(forKeys: [
				.isDirectoryKey
			]),
			let isDirectory = resourceValues.isDirectory,
			isDirectory
		else {
			continue
		}

		// Skip node_modules and hidden directories
		let dirName = entry.lastPathComponent
		if dirName.hasPrefix(".") || dirName == "node_modules" {
			continue
		}

		if let blockInfo = try getBlockInfo(
			at: entry,
			into: outputDirectory.appending(
				path: dirName,
				directoryHint: .isDirectory
			)
		) {
			blocks.append(blockInfo)
		} else {
			// If this directory is not a block, search its subdirectories
			try discoverBlocksRecursive(
				at: entry,
				into: outputDirectory,
				blocks: &blocks
			)
		}
	}
}

/// Gets block information from a specific path
/// - Parameter path: Path to check for a block (can be file or directory)
/// - Returns: BlockInfo if a valid block is found, nil otherwise
private func getBlockInfo(at path: URL, into outputDirectory: URL) throws
	-> BlockInfo?
{
	let fileManager = FileManager.default
	var isDirectory: ObjCBool = false

	guard fileManager.fileExists(atPath: path.path, isDirectory: &isDirectory)
	else {
		return nil
	}

	let blockDir: URL
	let indexPath: URL
	var inputFiles: [URL] = []
	var outputFiles: [URL] = []

	if isDirectory.boolValue {
		// It's a directory - look for index.ts or index.tsx
		blockDir = path

		let indexTsxPath = path.appending(path: "index.tsx")
		let indexTsPath = path.appending(path: "index.ts")

		if fileManager.fileExists(atPath: indexTsxPath.path) {
			indexPath = indexTsxPath
		} else if fileManager.fileExists(atPath: indexTsPath.path) {
			indexPath = indexTsPath
		} else {
			// No index file found
			return nil
		}
	} else {
		// It's a file - use its parent directory as the block directory
		blockDir = path.deletingLastPathComponent()
		indexPath = path
	}

	inputFiles.append(indexPath)
	outputFiles.append(outputDirectory)

	// Parse imports from the index file to determine dependencies
	if let content = try? String(contentsOf: indexPath, encoding: .utf8) {
		let importedFiles = extractImports(
			from: content,
			baseDirectory: blockDir
		)
		inputFiles.append(contentsOf: importedFiles)
	}

	// Get the block name from the directory
	let blockName = blockDir.lastPathComponent

	return BlockInfo(
		name: blockName,
		path: indexPath,
		inputFiles: inputFiles,
		outputFiles: outputFiles
	)
}

/// Extract import statements from TypeScript/TSX content
/// - Parameters:
///   - content: The file content to parse
///   - baseDirectory: The directory to resolve relative imports from
/// - Returns: Array of URLs to imported files
func extractImports(from content: String, baseDirectory: URL) -> [URL] {
	var imports: [URL] = []

	// Regex to match all non-type import styles with relative paths
	// Matches: import X from "./file", import { X } from "./file", import * as X from "./file"
	// Excludes: import type { X } from "./file"
	let regex = #/import\s+(?!type\s)(?:[^\s]+|\{[^}]+\}|\*\s+as\s+[^\s]+)\s+from\s+['\"](\.[^'\"]+)['\"]/#
	let matches = content.matches(of: regex)

	for match in matches {
		let importPath = String(match.output.1)
		// Normalize the path by resolving it and getting the standardized path
		let resolvedURL = baseDirectory.appending(path: importPath).standardized
		imports.append(resolvedURL)
	}

	return imports
}
