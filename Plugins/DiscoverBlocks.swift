// WARNING! This file should match the logic in discoverBlocks.ts in blockparty.
//  Keep any changes in sync with that file!!!

import Foundation
import PackagePlugin

/// Metadata and information about a discovered block
struct BlockInfo {
	let name: String
	let path: URL
	let dependencies: [URL]  // Files that are dependencies (index.ts/tsx, README.md, etc.)
}

/// Discovers all blocks in the target path
/// - Parameter targetPath: The directory to search for blocks
/// - Returns: Array of discovered block information
func discoverBlocks(at targetPath: URL) throws -> [BlockInfo] {
	var blocks: [BlockInfo] = []

	// Try to get block info for the target path itself
	if let blockInfo = try getBlockInfo(at: targetPath) {
		blocks.append(blockInfo)
		return blocks
	}

	// Check subdirectories for blocks
	let fileManager = FileManager.default
	guard
		let entries = try? fileManager.contentsOfDirectory(
			at: targetPath,
			includingPropertiesForKeys: [.isDirectoryKey],
			options: [.skipsHiddenFiles]
		)
	else {
		return blocks
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

		if let blockInfo = try getBlockInfo(at: entry) {
			blocks.append(blockInfo)
		}
	}

	return blocks
}

/// Gets block information from a specific path
/// - Parameter path: Path to check for a block (can be file or directory)
/// - Returns: BlockInfo if a valid block is found, nil otherwise
private func getBlockInfo(at path: URL) throws -> BlockInfo? {
	let fileManager = FileManager.default
	var isDirectory: ObjCBool = false

	guard fileManager.fileExists(atPath: path.path, isDirectory: &isDirectory)
	else {
		return nil
	}

	let blockDir: URL
	let indexPath: URL
	var dependencies: [URL] = []

	if isDirectory.boolValue {
		// It's a directory - look for index.ts or index.tsx
		blockDir = path

		let indexTsxPath = path.appendingPathComponent("index.tsx")
		let indexTsPath = path.appendingPathComponent("index.ts")

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

	// Add the index file as a dependency
	dependencies.append(indexPath)

	// Check for README.md in the block directory
	let readmePath = blockDir.appendingPathComponent("README.md")
	if fileManager.fileExists(atPath: readmePath.path) {
		dependencies.append(readmePath)
	}

	// Get the block name from the directory
	let blockName = blockDir.lastPathComponent

	return BlockInfo(
		name: blockName,
		path: indexPath,
		dependencies: dependencies
	)
}

/// Collects all input files for building blocks in a target path
/// - Parameter targetPath: The directory to search for blocks
/// - Returns: Array of URLs representing all input files (index.ts/tsx, README.md, etc.)
func collectInputFiles(at targetPath: URL) throws -> [URL] {
	let blocks = try discoverBlocks(at: targetPath)
	return blocks.flatMap { $0.dependencies }
}
