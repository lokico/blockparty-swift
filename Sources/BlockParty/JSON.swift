// Simplified https://github.com/iwill/generic-json-swift/blob/b010e534371c78cfba8f9a517a36577ad1d71501/GenericJSON/JSON.swift
//  (we only need encoding, not all the other fancy stuff)
public enum JSON: Equatable {
	case string(String)
	case number(Double)
	case object([String: JSON])
	case array([JSON])
	case bool(Bool)
	case null
}

extension JSON: Encodable {

	public func encode(to encoder: Encoder) throws {

		var container = encoder.singleValueContainer()

		switch self {
		case .array(let array):
			try container.encode(array)
		case .object(let object):
			try container.encode(object)
		case .string(let string):
			try container.encode(string)
		case .number(let number):
			try container.encode(number)
		case .bool(let bool):
			try container.encode(bool)
		case .null:
			try container.encodeNil()
		}
	}
}

extension JSON: ExpressibleByBooleanLiteral {

	public init(booleanLiteral value: Bool) {
		self = .bool(value)
	}
}

extension JSON: ExpressibleByNilLiteral {

	public init(nilLiteral: ()) {
		self = .null
	}
}

extension JSON: ExpressibleByArrayLiteral {

	public init(arrayLiteral elements: JSON...) {
		self = .array(elements)
	}
}

extension JSON: ExpressibleByDictionaryLiteral {

	public init(dictionaryLiteral elements: (String, JSON)...) {
		var object: [String: JSON] = [:]
		for (k, v) in elements {
			object[k] = v
		}
		self = .object(object)
	}
}

extension JSON: ExpressibleByFloatLiteral {

	public init(floatLiteral value: Double) {
		self = .number(value)
	}
}

extension JSON: ExpressibleByIntegerLiteral {

	public init(integerLiteral value: Int) {
		self = .number(Double(value))
	}
}

extension JSON: ExpressibleByStringLiteral {

	public init(stringLiteral value: String) {
		self = .string(value)
	}
}
