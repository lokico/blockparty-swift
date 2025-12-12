import Foundation
import Synchronization
import WebKit

public struct CachedResponse: Sendable {
	public let response: URLResponse
	public let data: Data

	/// The timestamp this value was cached. We only fetch a new value from the origin if it's newer than this.
	/// If this is `nil`, we always fetch a new value.
	public let timestamp: Date?

	public init(response: URLResponse, data: Data, timestamp: Date? = nil) {
		self.response = response
		self.data = data
		self.timestamp = timestamp
	}

	public static func upstream(for request: URLRequest) -> CachedResponse {
		fatalError("Not implemented")
	}
}

public final class BundleCache: URLSchemeHandler, Sendable {
	public static let scheme = "bp-cache"
	public static let shared = BundleCache()

	// These are all GET requests
	private let cache: Mutex<[URL: CachedResponse]> = Mutex([:])

	public func reply(for request: URLRequest) -> CachedResponse {
		// Reconstruct the canonical URL
		let requestURL = request.url!
		let canonicalURL = URL(
			string: "\(requestURL.host!):\(requestURL.path)"
		)!

		// If it's cached, return the cached entry
		if let cacheEntry = cache.withLock({ $0[canonicalURL] }) {
			return cacheEntry
		}

		// Otherwise, get upstream cached response and cache it
		let cacheResponse = CachedResponse.upstream(for: request)
		cache.withLock { $0[canonicalURL] = cacheResponse }
		return cacheResponse
	}

	public func precache(blockType: BlockType, baseURL: inout URL) {
		guard let precache = blockType.precache else { return }
		let cachedResponses = precache(baseURL)

		cache.withLock { cache in
			for new in cachedResponses {
				guard let url = new.response.url else { continue }

				// Don't replace existing cache value with precache value unless we know it's newer
				if let existing = cache[url] {
					guard let existingTimestamp = existing.timestamp,
						let newTimestamp = new.timestamp,
						newTimestamp > existingTimestamp
					else {
						continue
					}
				}

				cache[url] = new
			}
		}

		baseURL = URL(
			string: "\(BundleCache.scheme)://\(baseURL.absoluteString)"
		)!
	}

	/// Load a file from the given bundle and create a CachedURLResponse
	public static func cachedResponse(
		baseURL: URL,
		forResource name: String,
		withExtension ext: String,
		subdirectory: String?,
		contentType: String,
		in bundle: Bundle
	) -> CachedResponse? {
		guard
			let bundleURL = bundle.url(
				forResource: name,
				withExtension: ext,
				subdirectory: subdirectory
			),
			let data = try? Data(contentsOf: bundleURL)
		else {
			return nil
		}

		var url = baseURL
		if let subdirectory = subdirectory {
			url = url.appending(path: subdirectory, directoryHint: .isDirectory)
		}
		url = url.appending(
			path: "\(name).\(ext)",
			directoryHint: .notDirectory
		)

		let response = HTTPURLResponse(
			url: url,
			statusCode: 200,
			httpVersion: "HTTP/1.1",
			headerFields: ["Content-Type": contentType]
		)!

		return CachedResponse(response: response, data: data)
	}
}

extension CachedResponse: AsyncSequence {
	public func makeAsyncIterator() -> Iterator {
		Iterator(response: response, data: data)
	}

	public struct Iterator: AsyncIteratorProtocol {
		var response: URLResponse?
		var data: Data?

		public typealias Element = URLSchemeTaskResult
		public typealias Failure = any Error

		public mutating func next() async throws -> URLSchemeTaskResult? {
			if let response = self.response {
				self.response = nil
				return .response(response)
			}

			if let data = self.data {
				self.data = nil
				return .data(data)
			}

			return nil
		}
	}
}
