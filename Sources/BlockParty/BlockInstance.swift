import Foundation

public struct BlockInstance {

	let blockType: BlockType

	/// A closure that generates the JS expression containing props, given an encoding context
	let makeProps: (JSEncodingContext) throws -> String

	public init(
		type: BlockType,
		makeProps: @escaping (JSEncodingContext) throws -> String
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
		self.init(
			type: type,
			makeProps: { context in
				try dataToUTF8String(props.jsValue(context: context))
			}
		)
	}

	public init<B: Block>(of block: B) throws {
		try self.init(type: B.blockType, props: block)
	}
}

public func dataToUTF8String(_ data: Data) throws -> String {
	guard let str = String(data: data, encoding: .utf8) else {
		throw EncodingError.invalidValue(
			data,
			.init(
				codingPath: [],
				debugDescription: "Not valid UTF-8."
			)
		)
	}
	return str
}
