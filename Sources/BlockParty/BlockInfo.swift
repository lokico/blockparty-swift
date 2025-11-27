import Foundation

public struct BlockInfo {
	/// The canonical URL to use in the JS import of the Block.
	let url: URL

	/// Data to precache for the Block's `url`
	let cachedContent: (() -> Data)?

	/// A JSON string containing the props to use when instantiating the Block.
	let propsJSON: String

	public init(url: URL, cachedContent: (() -> Data)? = nil, propsJSON: String)
	{
		self.url = url
		self.cachedContent = cachedContent
		self.propsJSON = propsJSON
	}

	public init<Props: Encodable>(
		url: URL,
		cachedContent: (() -> Data)? = nil,
		props: Props
	) throws {
		self.url = url
		self.cachedContent = cachedContent

		let encoder = JSONEncoder()
		let data = try encoder.encode(props)
		guard let str = String(data: data, encoding: .utf8) else {
			throw EncodingError.invalidValue(
				props,
				EncodingError.Context(
					codingPath: [],
					debugDescription:
						"Encoding props to JSON produced invalid UTF-8"
				)
			)
		}
		self.propsJSON = str
	}
}
