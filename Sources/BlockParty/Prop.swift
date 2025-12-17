import Foundation

// Inspired by https://github.com/iwill/generic-json-swift/blob/b010e534371c78cfba8f9a517a36577ad1d71501/GenericJSON/JSON.swift
//  (we only need encoding, not all the other fancy stuff)
public enum Prop {
	case string(String)
	case number(Double)
	case object([String: Prop])
	case array([Prop])
	case bool(Bool)
	case null
}

extension Prop: JSEncodable {
	public func jsValue(context: JSEncodingContext) throws -> String {
		switch self {
		case .array(let array):
			var parts: [String] = []
			for element in array {
				parts.append(try element.jsValue(context: context))
			}
			return "[" + parts.joined(separator: ",") + "]"
		case .object(let object):
			var parts: [String] = []
			for (key, value) in object {
				let encodedKey = try dataToUTF8String(JSONEncoder().encode(key))
				let encodedValue = try value.jsValue(context: context)
				parts.append("\(encodedKey):\(encodedValue)")
			}
			return "{" + parts.joined(separator: ",") + "}"
		case .string(let string):
			return try dataToUTF8String(JSONEncoder().encode(string))
		case .number(let number):
			return try dataToUTF8String(JSONEncoder().encode(number))
		case .bool(let bool):
			return bool ? "true" : "false"
		case .null:
			return "null"
		}
	}
}

extension Prop: ExpressibleByBooleanLiteral {

	public init(booleanLiteral value: Bool) {
		self = .bool(value)
	}
}

extension Prop: ExpressibleByNilLiteral {

	public init(nilLiteral: ()) {
		self = .null
	}
}

extension Prop: ExpressibleByArrayLiteral {

	public init(arrayLiteral elements: Prop...) {
		self = .array(elements)
	}
}

extension Prop: ExpressibleByDictionaryLiteral {

	public init(dictionaryLiteral elements: (String, Prop)...) {
		self = .object(Dictionary(uniqueKeysWithValues: elements))
	}
}

extension Prop: ExpressibleByFloatLiteral {

	public init(floatLiteral value: Double) {
		self = .number(value)
	}
}

extension Prop: ExpressibleByIntegerLiteral {

	public init(integerLiteral value: Int) {
		self = .number(Double(value))
	}
}

extension Prop: ExpressibleByStringLiteral {

	public init(stringLiteral value: String) {
		self = .string(value)
	}
}
