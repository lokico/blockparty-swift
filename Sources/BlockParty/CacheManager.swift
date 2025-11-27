import Foundation
import Synchronization

/// Manages the pre-caching of Blocks,
// - Run a HEAD request on the URL to ensure there aren't newer versions?
final class CacheManager: Sendable {
	private let cachedURLs: Mutex<Set<URL>> = Mutex(Set())

	public static let shared: CacheManager = .init()

	public func ensureCached(blockInfo: BlockInfo) {
		guard let contentFunc = blockInfo.cachedContent else { return }
		let url = blockInfo.url

		let inserted = cachedURLs.withLock { cachedURLs in
			let (inserted, _) = cachedURLs.insert(url)
			return inserted
		}
		if !inserted { return }

		let data = contentFunc()

		// According to the docs, URLCache is thread safe
		URLCache.shared.storeCachedResponse(
			CachedURLResponse(
				response: URLResponse(
					url: url,
					mimeType: "text/javascript",
					expectedContentLength: data.count,
					textEncodingName: nil
				),
				data: data
			),
			for: URLRequest(url: url)
		)
	}
}
