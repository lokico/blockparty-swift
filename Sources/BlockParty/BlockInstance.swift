import Foundation

public struct BlockInstance {
	let blockType: BlockType

	/// A closure that generates the JS expression containing props, given an encoding context
	let makeProps: (any JSEncodingContext) throws -> String

	public init(
		type: BlockType,
		makeProps: @escaping (any JSEncodingContext) throws -> String
	) {
		self.blockType = type
		self.makeProps = makeProps
	}

	@_disfavoredOverload
	public init<Props: Encodable>(
		type: BlockType,
		props: Props
	) throws {
		self.init(
			type: type,
			makeProps: { _ in
				try dataToUTF8String(JSONEncoder().encode(props))
			}
		)
	}

	public init<Props: JSEncodable>(
		type: BlockType,
		props: Props
	) throws {
		self.init(type: type, makeProps: props.jsValue)
	}
}
