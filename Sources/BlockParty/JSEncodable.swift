import Foundation

/// Context for encoding JavaScript values, allowing registration of Swift callbacks
public protocol JSEncodingContext {
	/// Register a synchronous Swift closure that can be called from JavaScript
	/// Returns a JavaScript expression that will call this closure synchronously
	func registerSyncCallback(
		_ callback: @escaping (String) throws -> String?
	) -> String

	/// Register an async Swift closure that can be called from JavaScript
	/// Returns a JavaScript expression that will call this closure asynchronously
	func registerAsyncCallback(
		_ callback: @escaping (String) async throws -> String?
	) -> String
}

/// A superset of `Encodable` that also allows for arbitrary JavaScript expressions (e.g. lambda, Date, etc)
public protocol JSEncodable {
	func jsValue(context: any JSEncodingContext) throws -> String
}

extension JSEncodable where Self: Encodable {
	public func jsValue(context: any JSEncodingContext) throws -> String {
		return try dataToUTF8String(JSONEncoder().encode(self))
	}
}

// Also called from BlockPartyTool generated jsValue implementations
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
