import Foundation

struct BlockMetadata: Decodable {
	let name: String
	let description: String?
	let metadata: [String: String]?
	let readme: String?

	let propDefinitions: [PropDefinition]
	let js: String
	let css: [String]
	let assets: [String]

	// Sync with build.ts in BlockParty
	var subdirectory: String {
		let blockId = metadata?["id"] ?? name
		return blockId.replacing(/[^a-zA-Z0-9-_]/, with: "-")
	}
}

enum PropType: Decodable {
	case primitive(syntax: String)
	case object(syntax: String, properties: [PropDefinition])
	case function(syntax: String, parameters: [PropDefinition])
	case union(syntax: String, types: [PropType])
	case constant(syntax: String, value: Any)
	indirect case array(syntax: String, elementType: PropType)
	case tuple(syntax: String, types: [PropType])

	enum CodingKeys: String, CodingKey {
		case kind, syntax, properties, parameters, types, value, elementType
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let kind = try container.decode(String.self, forKey: .kind)
		let syntax = try container.decode(String.self, forKey: .syntax)

		switch kind {
		case "primitive":
			self = .primitive(syntax: syntax)
		case "object":
			let properties = try container.decode(
				[PropDefinition].self,
				forKey: .properties
			)
			self = .object(syntax: syntax, properties: properties)
		case "function":
			let parameters = try container.decode(
				[PropDefinition].self,
				forKey: .parameters
			)
			self = .function(syntax: syntax, parameters: parameters)
		case "union":
			let types = try container.decode([PropType].self, forKey: .types)
			self = .union(syntax: syntax, types: types)
		case "constant":
			let value = try JSONSerialization.jsonObject(
				with: Data(syntax.utf8),
				options: [.fragmentsAllowed]
			)
			self = .constant(syntax: syntax, value: value)
		case "array":
			let elementType = try container.decode(
				PropType.self,
				forKey: .elementType
			)
			self = .array(syntax: syntax, elementType: elementType)
		case "tuple":
			let types = try container.decode([PropType].self, forKey: .types)
			self = .tuple(syntax: syntax, types: types)
		default:
			throw DecodingError.dataCorruptedError(
				forKey: .kind,
				in: container,
				debugDescription: "Unknown kind: \(kind)"
			)
		}
	}

	var syntax: String {
		switch self {
		case .primitive(let syntax),
			.object(let syntax, _),
			.function(let syntax, _),
			.union(let syntax, _),
			.constant(let syntax, _),
			.array(let syntax, _),
			.tuple(let syntax, _):
			return syntax
		}
	}
}

struct PropDefinition: Decodable {
	let name: String
	let type: PropType
	let optional: Bool
	let description: String?
}

struct BuildOutput: Decodable {
	let blocks: [BlockMetadata]
	let importmap: [String: String]
}

struct BlockPartyTool {
	static func main() async {
		let arguments = CommandLine.arguments

		guard arguments.count >= 3 else {
			print("Usage: BlockPartyTool-tool <package-dir> <output-dir>")
			exit(1)
		}

		let packageDir = arguments[1]
		let outputDir = arguments[2]

		do {
			try await buildBlocks(packageDir: packageDir, outputDir: outputDir)
		} catch let buildError as BuildError {
			print("❌ Build failed: \(buildError)")
			switch buildError {
			case .processFailure:
				print(
					"💡 Make sure your project has an NPM package.json file with 'blockparty' as a devDependency and that you've run 'npm install'."
				)
			}
			exit(1)
		} catch {
			print("❌ Build failed: \(error)")
			exit(1)
		}
	}

	static func buildBlocks(packageDir: String, outputDir: String) async throws
	{
		let packageURL = URL(fileURLWithPath: packageDir)
		let outputURL = URL(fileURLWithPath: outputDir)

		// Run npx blockparty command
		let process = Process()
		process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
		let args = [
			"npx", "--no", "--offline", "blockparty", "build", "--individually",
			packageDir,
			outputDir,
		]
		process.arguments = args
		process.currentDirectoryURL = packageURL

		let outputPipe = Pipe()
		let errorPipe = Pipe()
		process.standardOutput = outputPipe
		process.standardError = errorPipe

		print("🚀 Running: \(args.joined(separator: " "))")

		try process.run()

		// Read output
		let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
		if let output = String(data: outputData, encoding: .utf8),
			!output.isEmpty
		{
			print(output)
		}

		// Read errors
		let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
		if let errorOutput = String(data: errorData, encoding: .utf8),
			!errorOutput.isEmpty
		{
			print(errorOutput)
		}

		process.waitUntilExit()

		guard process.terminationStatus == 0 else {
			throw BuildError.processFailure(exitCode: process.terminationStatus)
		}

		print("\n📋 Reading build output from index.json...")
		let indexPath = outputURL.appending(path: "index.json")
		let indexData = try Data(contentsOf: indexPath)
		let buildOutput = try JSONDecoder().decode(
			BuildOutput.self,
			from: indexData
		)

		print(
			"✨ Generating Swift code for \(buildOutput.blocks.count) block(s)..."
		)
		let generatedCode = generateSwiftCode(
			for: buildOutput,
			outputDir: outputDir
		)

		let generatedFilePath = outputURL.appending(
			path: "BlockParty-Generated.swift"
		)
		try generatedCode.write(
			to: generatedFilePath,
			atomically: true,
			encoding: .utf8
		)

		print("✅ Generated BlockParty-Generated.swift")
	}

	static func generateSwiftCode(
		for buildOutput: BuildOutput,
		outputDir: String
	) -> String {
		var code = """
			// This file is auto-generated by BlockPartyTool. Do not edit manually.
			import Foundation
			import BlockParty


			"""

		for block in buildOutput.blocks {
			code += generateBlockStruct(
				for: block,
				importMap: buildOutput.importmap,
				outputDir: outputDir
			)
			code += "\n\n"
		}

		return code
	}

	static func generateBlockStruct(
		for block: BlockMetadata,
		importMap: [String: String],
		outputDir: String
	) -> String {
		let structName = swiftIdentifier(for: block.name)

		let structInfo = generateStruct(
			name: structName,
			description: block.description,
			baseConformance: "Block",
			properties: block.propDefinitions,
			indent: ""
		)

		var code = structInfo.openingCode

		// Add static blockType property
		code += "\n"
		code += "\tpublic static var blockType: BlockType {\n"
		code += "\t\tBlockType(\n"
		code += "\t\t\tjs: \"\(block.js)\",\n"
		if !block.css.isEmpty {
			code +=
				"\t\t\tcss: [\(block.css.map { "\"\($0)\"" }.joined(separator: ", "))],\n"
		} else {
			code += "\t\t\tcss: [],\n"
		}

		// Add import map
		code += "\t\t\timportMap: [\n"
		for (key, value) in importMap.sorted(by: { $0.key < $1.key }) {
			code += "\t\t\t\t\"\(key)\": \"\(value)\",\n"
		}
		code += "\t\t\t]) { baseURL in\n"

		// Add precache closure
		code += "\t\t\t\t[\n"

		// Precache the JS file
		let jsFileName = URL(fileURLWithPath: block.js).lastPathComponent
		let jsFileNameWithoutExt = jsFileName.replacingOccurrences(
			of: ".js",
			with: ""
		)
		code += "\t\t\t\t\tBundleCache.cachedResponse(\n"
		code += "\t\t\t\t\t\tbaseURL: baseURL,\n"
		code += "\t\t\t\t\t\tforResource: \"\(jsFileNameWithoutExt)\",\n"
		code += "\t\t\t\t\t\twithExtension: \"js\",\n"
		code += "\t\t\t\t\t\tsubdirectory: \"\(block.subdirectory)\",\n"
		code += "\t\t\t\t\t\tcontentType: \"application/javascript\",\n"
		code += "\t\t\t\t\t\tin: .module\n"
		code += "\t\t\t\t\t),\n"

		// Precache CSS files
		for cssPath in block.css {
			let cssFileName = URL(fileURLWithPath: cssPath).lastPathComponent
			let cssFileNameWithoutExt = cssFileName.replacingOccurrences(
				of: ".css",
				with: ""
			)
			code += "\t\t\t\t\tBundleCache.cachedResponse(\n"
			code += "\t\t\t\t\t\tbaseURL: baseURL,\n"
			code += "\t\t\t\t\t\tforResource: \"\(cssFileNameWithoutExt)\",\n"
			code += "\t\t\t\t\t\twithExtension: \"css\",\n"
			code += "\t\t\t\t\t\tsubdirectory: \"\(block.subdirectory)\",\n"
			code += "\t\t\t\t\t\tcontentType: \"text/css\",\n"
			code += "\t\t\t\t\t\tin: .module\n"
			code += "\t\t\t\t\t),\n"
		}

		code += "\t\t\t\t].compactMap { $0 }\n"
		code += "\t\t\t}\n"
		code += "\t}\n"

		code += "}"

		return code
	}

	struct MappedType {
		let propType: PropType
		let swiftType: String
		let isEncodable: Bool
		let isOptional: Bool
	}

	struct StructInfo {
		let name: String
		let openingCode: String
		let isEncodable: Bool
	}

	// Helper function to process properties with nested struct generation
	static func processProperties(
		properties: [PropDefinition],
		indent: String
	) -> (
		mappedProps: [(prop: PropDefinition, mapped: MappedType)],
		nestedStructInfos: [StructInfo],
		isEncodable: Bool
	) {
		var mappedProps: [(prop: PropDefinition, mapped: MappedType)] = []
		var nestedStructInfos: [StructInfo] = []
		var isEncodable = true

		// First pass: recursively generate nested structs for properties with nested properties
		for prop in properties {
			if case .object(_, let nestedProps) = prop.type {
				let nestedStructName =
					swiftIdentifier(for: prop.name).prefix(1).uppercased()
					+ swiftIdentifier(for: prop.name).dropFirst()
				let nestedStructInfo = generateStruct(
					name: String(nestedStructName),
					baseConformance: "JSEncodable",
					properties: nestedProps,
					indent: indent + "\t"
				)
				nestedStructInfos.append(nestedStructInfo)
			}
		}

		// Second pass: map all properties
		for prop in properties {
			let mapped: MappedType
			if case .object = prop.type {
				// This is a nested object type - use the generated struct name
				let nestedStructName =
					swiftIdentifier(for: prop.name).prefix(1).uppercased()
					+ swiftIdentifier(for: prop.name).dropFirst()
				let nestedInfo = nestedStructInfos.first {
					$0.name == nestedStructName
				}!
				mapped = MappedType(
					propType: prop.type,
					swiftType: String(nestedStructName)
						+ (prop.optional ? "?" : ""),
					isEncodable: nestedInfo.isEncodable,
					isOptional: prop.optional,
				)
			} else {
				mapped = mapTypeScriptTypeToSwift(
					prop.type,
					isOptional: prop.optional
				)
			}
			isEncodable = isEncodable && mapped.isEncodable
			mappedProps.append((prop: prop, mapped: mapped))
		}

		return (mappedProps, nestedStructInfos, isEncodable)
	}

	// Helper function to generate property declarations
	static func generateProperties(
		mappedProps: [(prop: PropDefinition, mapped: MappedType)],
		indent: String
	) -> String {
		var code = ""
		for (prop, mapped) in mappedProps {
			if let description = prop.description {
				code += "\(indent)/// \(description)\n"
			}
			code +=
				"\(indent)public let \(swiftIdentifier(for: prop.name)): \(mapped.swiftType)\n"
		}
		return code
	}

	// Helper function to generate initializer
	static func generateInitializer(
		mappedProps: [(prop: PropDefinition, mapped: MappedType)],
		indent: String
	) -> String {
		var code = ""
		code += "\n"
		code += "\(indent)public init(\n"
		for (index, (prop, mapped)) in mappedProps.enumerated() {
			let comma = index < mappedProps.count - 1 ? "," : ""
			let escaping =
				if case .function = mapped.propType, !mapped.isOptional {
					"@escaping "
				} else { "" }

			code +=
				"\(indent)\t\(swiftIdentifier(for: prop.name)): \(escaping)\(mapped.swiftType)\(comma)\n"
		}
		code += "\(indent)) {\n"
		for (prop, _) in mappedProps {
			let propName = swiftIdentifier(for: prop.name)
			code += "\(indent)\tself.\(propName) = \(propName)\n"
		}
		code += "\(indent)}\n"
		return code
	}

	// Helper function to generate function callback registration code
	static func generateFunctionCallback(
		propName: String,
		mapped: MappedType,
		parameters: [PropDefinition]?,
		indent: String
	) -> String {
		var code = ""

		// Strip optional ? and parentheses when checking return type
		var baseType = mapped.swiftType
		if baseType.hasSuffix("?") {
			baseType = String(baseType.dropLast())
		}
		// Strip outer parentheses wrapping the function type
		// e.g., ((() -> Void)) becomes () -> Void
		while baseType.hasPrefix("(") && baseType.hasSuffix(")") {
			baseType = String(baseType.dropFirst().dropLast())
		}

		// Check if function is async
		let isAsync = baseType.contains(" async ")

		// Extract return type from function signature
		let returnType: String
		if let arrowIndex = baseType.range(of: "->", options: .backwards) {
			returnType = baseType[arrowIndex.upperBound...].trimmingCharacters(
				in: .whitespaces
			)
		} else {
			returnType = "Void"
		}

		// Use appropriate callback registration based on whether function is async
		if isAsync {
			code += "context.registerAsyncCallback { args in\n"
		} else {
			code += "context.registerSyncCallback { args in\n"
		}

		// Parse parameters and call function using JSCall
		let awaitKeyword = isAsync ? "await " : ""
		if let params = parameters, !params.isEmpty {
			// Build JSCall generic type with return type and parameter types
			let paramTypes = params.map { param in
				mapTypeScriptTypeToSwift(
					param.type,
					isOptional: param.optional
				).swiftType
			}.joined(separator: ", ")

			code += "\(indent)\tlet argsData = Data(args.utf8)\n"
			code +=
				"\(indent)\tlet jsCall = try JSONDecoder().decode(JSCall<\(returnType), \(paramTypes)>.self, from: argsData)\n"
			code +=
				"\(indent)\treturn try \(awaitKeyword)jsCall.invoke(\(propName))\n"
		} else {
			// No parameters
			if returnType != "Void" && returnType != "()" {
				code += "\(indent)\tlet result = \(awaitKeyword)\(propName)()\n"
				code +=
					"\(indent)\treturn try BlockParty.dataToUTF8String(JSONEncoder().encode(result))\n"
			} else {
				code += "\(indent)\t\(awaitKeyword)\(propName)()\n"
				code += "\(indent)\treturn nil\n"
			}
		}

		code += "\(indent)}\n"
		return code
	}

	// Helper function to generate jsValue implementation
	static func generateJSValue(
		mappedProps: [(prop: PropDefinition, mapped: MappedType)],
		indent: String
	) -> String {
		var code = ""
		code += "\n"
		code +=
			"\(indent)public func jsValue(context: any JSEncodingContext) throws -> String {\n"

		// Check if any property is encodable
		let hasEncodableMembers = mappedProps.contains { $0.mapped.isEncodable }
		if hasEncodableMembers {
			code += "\(indent)\tlet encoder = JSONEncoder()\n"
		}

		code += "\(indent)\tvar jsExpr = \"{\"\n"
		for (index, (prop, mapped)) in mappedProps.enumerated() {
			let propName = swiftIdentifier(for: prop.name)
			if index > 0 {
				code += "\(indent)\tjsExpr += \",\"\n"
			}
			code += "\(indent)\tjsExpr += \"\\\"\(prop.name)\\\":\"\n"

			switch mapped.propType {
			case .function(_, let parameters):
				if mapped.isOptional {
					code += "\(indent)\tif let \(propName)Fn = \(propName) {\n"
					code += "\(indent)\t\tjsExpr += "
					code += generateFunctionCallback(
						propName: "\(propName)Fn",
						mapped: mapped,
						parameters: parameters,
						indent: "\(indent)\t\t"
					)
					code += "\(indent)\t} else {\n"
					code += "\(indent)\t\tjsExpr += \"undefined\"\n"
					code += "\(indent)\t}\n"
				} else {
					code += "\(indent)\tjsExpr += "
					code += generateFunctionCallback(
						propName: propName,
						mapped: mapped,
						parameters: parameters,
						indent: "\(indent)\t"
					)
				}
			case .object:
				// Nested object - call its jsValue method
				if mapped.isOptional {
					code += "\(indent)\tif let \(propName)Val = \(propName) {\n"
					code +=
						"\(indent)\t\tjsExpr += try \(propName)Val.jsValue(context: context)\n"
					code += "\(indent)\t} else {\n"
					code += "\(indent)\t\tjsExpr += \"null\"\n"
					code += "\(indent)\t}\n"
				} else {
					code +=
						"\(indent)\tjsExpr += try \(propName).jsValue(context: context)\n"
				}
			default:
				// Regular Encodable property
				code +=
					"\(indent)\tjsExpr += try BlockParty.dataToUTF8String(encoder.encode(\(propName)))\n"
			}
		}
		code += "\(indent)\tjsExpr += \"}\"\n"
		code += "\(indent)\treturn jsExpr\n"
		code += "\(indent)}\n"
		return code
	}

	static func generateStruct(
		name: String,
		description: String? = nil,
		baseConformance: String,
		properties: [PropDefinition],
		indent: String
	) -> StructInfo {
		var code = ""
		var indent = indent

		// Add documentation if available
		if let description = description {
			code += "\(indent)/// \(description)\n"
		}

		// Process properties using shared helper
		let (mappedProps, nestedStructInfos, isEncodable) = processProperties(
			properties: properties,
			indent: indent
		)

		code +=
			"\(indent)public struct \(name): \(baseConformance)\(isEncodable ? ", Encodable" : "") {\n"

		indent += "\t"

		// Generate nested struct definitions
		for info in nestedStructInfos {
			code += info.openingCode
			code += "\(indent)}\n"
		}

		// Generate properties using helper
		code += generateProperties(mappedProps: mappedProps, indent: indent)

		// Generate initializer using helper
		code += generateInitializer(mappedProps: mappedProps, indent: indent)

		// If not encodable, generate custom jsValue implementation using helper
		if !isEncodable {
			code += generateJSValue(mappedProps: mappedProps, indent: indent)
		}

		return StructInfo(
			name: name,
			openingCode: code,
			isEncodable: isEncodable
		)
	}

	static func mapPrimitiveTypeToSwift(_ typeStr: String) -> String {
		let cleanType = typeStr.trimmingCharacters(in: .whitespaces)
		switch cleanType {
		case "string":
			return "String"
		case "number":
			return "Double"
		case "boolean":
			return "Bool"
		case "any":
			return "Any"
		case "void", "undefined", "null":
			return "Void"
		default:
			return cleanType
		}
	}

	static func mapTypeScriptTypeToSwift(
		_ propType: PropType,
		isOptional: Bool
	)
		-> MappedType
	{
		var isEncodable = true
		var isFunction = false
		var mappedType: String

		switch propType {
		case .primitive(let syntax):
			mappedType = mapPrimitiveTypeToSwift(syntax)

		case .function(let syntax, let parameters):
			// Handle function types
			isEncodable = false
			isFunction = true

			let paramTypes = parameters.map { param in
				mapTypeScriptTypeToSwift(
					param.type,
					isOptional: param.optional
				).swiftType
			}

			// Parse return type from syntax (after =>)
			// First strip outer parentheses if present: (() => void) -> () => void
			var cleanType = syntax.trimmingCharacters(in: .whitespaces)
			if cleanType.hasPrefix("(") && cleanType.hasSuffix(")") {
				cleanType = String(cleanType.dropFirst().dropLast())
					.trimmingCharacters(in: .whitespaces)
			}

			let parts = cleanType.split(separator: "=>", maxSplits: 1)
			let returnType: String
			let isAsync: Bool
			if parts.count == 2 {
				var returnTypeStr = parts[1].trimmingCharacters(
					in: .whitespaces
				)
				// Strip trailing parenthesis if present
				if returnTypeStr.hasSuffix(")") && !returnTypeStr.contains("(")
				{
					returnTypeStr = String(returnTypeStr.dropLast())
						.trimmingCharacters(in: .whitespaces)
				}
				// Check if return type is Promise<T>
				if returnTypeStr.hasPrefix("Promise<")
					&& returnTypeStr.hasSuffix(">")
				{
					isAsync = true
					// Extract T from Promise<T>
					let innerType = returnTypeStr.dropFirst(
						"Promise<".count
					).dropLast()
					returnType = mapPrimitiveTypeToSwift(String(innerType))
				} else {
					isAsync = false
					returnType = mapPrimitiveTypeToSwift(returnTypeStr)
				}
			} else {
				isAsync = false
				returnType = "Void"
			}

			// Build Swift function type without parameter labels
			let asyncKeyword = isAsync ? " async" : ""
			if paramTypes.isEmpty {
				mappedType = "()\(asyncKeyword) -> \(returnType)"
			} else {
				mappedType =
					"(\(paramTypes.joined(separator: ", ")))\(asyncKeyword) -> \(returnType)"
			}

		case .union(let syntax, let types):
			// Filter out undefined types
			let nonUndefinedTypes = types.filter { type in
				if case .primitive(let syn) = type, syn == "undefined" {
					return false
				}
				return true
			}

			if nonUndefinedTypes.count < types.count {
				if nonUndefinedTypes.count == 1 {
					// Single type with undefined - map it as optional
					return mapTypeScriptTypeToSwift(
						nonUndefinedTypes[0],
						isOptional: true
					)
				} else {
					// Multiple types with undefined - create a union without undefined and map as optional
					let newSyntax = nonUndefinedTypes.map { $0.syntax }.joined(
						separator: " | "
					)
					let newUnion = PropType.union(
						syntax: newSyntax,
						types: nonUndefinedTypes
					)
					return mapTypeScriptTypeToSwift(newUnion, isOptional: true)
				}
			} else {
				// No undefined in union, just use the syntax
				mappedType = syntax
			}

		case .constant(let syntax, _):
			// Constants are typically string literals, use the syntax
			mappedType = syntax

		case .array(let syntax, _):
			// Use the syntax which should be something like "Type[]"
			mappedType = syntax

		case .tuple(let syntax, _):
			// Use the syntax which should be something like "[Type1, Type2]"
			mappedType = syntax

		case .object(let syntax, _):
			// Object types should be handled separately as nested structs
			// This shouldn't typically be reached
			mappedType = syntax
		}

		if isOptional {
			// For function types, wrap in parentheses before adding ?
			// e.g., (() -> Void)? instead of () -> Void?
			if isFunction {
				mappedType = "(\(mappedType))?"
			} else {
				mappedType += "?"
			}
		}

		return MappedType(
			propType: propType,
			swiftType: mappedType,
			isEncodable: isEncodable,
			isOptional: isOptional,
		)
	}

	static func swiftIdentifier(for name: String) -> String {
		// Replace hyphens with underscores and handle Swift keywords
		let sanitized = name.replacingOccurrences(of: "-", with: "_")

		// Check if it's a Swift keyword and escape it
		let swiftKeywords = [
			"associatedtype", "class", "deinit", "enum", "extension",
			"fileprivate",
			"func", "import", "init", "inout", "internal", "let", "open",
			"operator",
			"private", "precedencegroup", "protocol", "public", "rethrows",
			"static",
			"struct", "subscript", "typealias", "var", "break", "case", "catch",
			"continue", "default", "defer", "do", "else", "fallthrough", "for",
			"guard",
			"if", "in", "repeat", "return", "throw", "switch", "where", "while",
			"as",
			"false", "is", "nil", "self", "Self", "super", "throws", "true",
			"try",
		]

		if swiftKeywords.contains(sanitized) {
			return "`\(sanitized)`"
		}

		return sanitized
	}
}

enum BuildError: Error, CustomStringConvertible {
	case processFailure(exitCode: Int32)

	var description: String {
		switch self {
		case .processFailure(let exitCode):
			return "npx blockparty process failed with exit code \(exitCode)"
		}
	}
}
