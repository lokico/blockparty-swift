import Foundation

public struct BlockType {
	/// The path to combine with a base URL to form the canonical URL for the JS import of the Block.
	public let jsPath: String

	/// The path to combine with a base URL to form the canonical URLs  for `<link rel="stylesheet">`
	///  elements.
	public let cssPaths: [String]

	/// The import map for resolving JavaScript module imports
	public let importMap: [String: String]

	/// Data to precache for this Block
	public let precache: ((_ baseURL: URL) -> [CachedResponse])?

	public init(
		js path: String,
		css paths: [String] = [],
		importMap: [String: String] = [:],
		precache: ((_ baseURL: URL) -> [CachedResponse])? = nil
	) {
		self.jsPath = path
		self.cssPaths = paths
		self.importMap = importMap
		self.precache = precache
	}
}
