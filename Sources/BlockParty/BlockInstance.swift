import Foundation

public struct BlockInstance {

	let blockType: BlockType

	/// A JSON string containing the props to use when instantiating the Block.
	let propsJSON: String

	public init(
		type: BlockType,
		propsJSON: String
	) {
		self.blockType = type
		self.propsJSON = propsJSON
	}

	public init<Props: Encodable>(
		type: BlockType,
		props: Props
	) throws {
		let encoder = JSONEncoder()
		let data = try encoder.encode(props)
		guard let str = String(data: data, encoding: .utf8) else {
			throw EncodingError.invalidValue(
				data,
				.init(
					codingPath: [],
					debugDescription: "Failed to encode props to UTF-8."
				)
			)
		}
		self.init(type: type, propsJSON: str)
	}

	public init<B: Block & Encodable>(of block: B) throws {
		try self.init(type: B.blockType, props: block)
	}
}
