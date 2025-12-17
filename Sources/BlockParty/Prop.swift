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
	public func jsValue(context: JSEncodingContext) throws -> Data {
		switch self {
		case .array(let array):
			var first = true
			var data = Data()
			data.append(0x5b)  // [
			for element in array {
				if !first { data.append(0x2c) }  // ,
				data.append(try element.jsValue(context: context))
				first = false
			}
			data.append(0x5d)  // ]
			return data
		case .object(let object):
			var first = true
			var data = Data()
			let encoder = JSONEncoder()
			data.append(0x7b)  // {
			for (key, value) in object {
				if !first { data.append(0x2c) }  // ,
				data.append(try encoder.encode(key))
				data.append(0x3a)  // :
				data.append(try value.jsValue(context: context))
				first = false
			}
			data.append(0x7d)  // }
			return data
		case .string(let string):
			return try JSONEncoder().encode(string)
		case .number(let number):
			return try JSONEncoder().encode(number)
		case .bool(let bool):
			return Data(
				bool
					? [0x74, 0x72, 0x75, 0x65]  // "true" in utf8 bytes
					: [0x66, 0x61, 0x6c, 0x73, 0x65]  // "false" in utf8 bytes
			)
		case .null:
			return Data([0x6e, 0x75, 0x6c, 0x6c])  // "null" in utf8 bytes
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
