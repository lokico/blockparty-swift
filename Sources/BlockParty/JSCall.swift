import Foundation

public struct JSCall<R, each Arg> {
	private let args: (repeat each Arg)
}

extension JSCall: Decodable where repeat (each Arg): Decodable {
	public init(from decoder: any Decoder) throws {
		var container = try decoder.unkeyedContainer()
		self.args = (repeat try container.decode((each Arg).self))
	}
}

extension JSCall where R: Encodable {
	public func invoke(_ fn: (repeat each Arg) -> R) throws -> String {
		let result = fn(repeat each args)
		let data = try JSONEncoder().encode(result)
		return try dataToUTF8String(data)
	}

	public func invoke(_ fn: (repeat each Arg) async -> R) async throws
		-> String
	{
		let result = await fn(repeat each args)
		let data = try JSONEncoder().encode(result)
		return try dataToUTF8String(data)
	}
}
